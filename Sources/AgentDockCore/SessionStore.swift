import Foundation
import Observation

@MainActor
@Observable
public final class SessionStore {
    public private(set) var sessions: [AgentSession] = []

    /// 无活动超过该时长 → disconnected
    public var disconnectAfter: TimeInterval = 10 * 60
    /// 无活动超过该时长 → 从列表移除
    public var removeAfter: TimeInterval = 2 * 60 * 60
    /// 事件环形缓冲上限
    public static let maxRecentEvents = 20

    /// Claude 会话准入校验(注册表过滤子 agent / 工具会话);nil = 不过滤
    public var claudeSessionValidator: ((String) -> Bool)?

    /// Codex 会话存活判定(按 cwd 匹配活进程);nil = 不判定。
    /// CLI 退出后 SQLite/rollout 都不会记录死亡,只能靠进程表反查。
    public var codexLivenessCheck: ((AgentSession) -> Bool)?

    /// Cursor 会话准入校验(过滤 Task/best-of-N 派生的子 agent);nil = 不过滤
    public var cursorSessionValidator: ((String) -> Bool)?
    /// Cursor 父会话是否仍有活跃子任务；用于阻止回填 done 抢先结束父会话。
    public var cursorHasActiveSubagents: ((String) -> Bool)?

    /// 状态转换观察者(历史记录用):newState = nil 表示会话被移除
    public var transitionObserver: ((_ sessionId: String, _ kind: AgentKind, _ project: String,
                                     _ newState: SessionState?) -> Void)?
    /// token 变化观察者(历史记录用)
    public var tokenObserver: ((_ sessionId: String, _ kind: AgentKind, _ tokens: Int) -> Void)?
    /// 工具调用观察者(库存页统计用):第三方工具 begin/end
    public var toolCallObserver: ((_ sessionId: String, _ kind: AgentKind,
                                   _ toolKey: String, _ toolRaw: String?,
                                   _ phase: ToolCallPhase, _ at: Date) -> Void)?
    private var observedStates: [String: SessionState] = [:]
    private var observedTokens: [String: Int] = [:]
    private var observedMeta: [String: (kind: AgentKind, project: String)] = [:]
    /// 去重 + 配对:会话当前进行中的第三方工具
    private var openThirdPartyTool: [String: (key: String, at: Date)] = [:]

    /// 对比上次快照,把状态/token 变化通知观察者。
    /// 集中做 diff 而不是在每个修改点埋回调:mutation 入口多(事件/回填/清理/审批),
    /// 漏一个就丢数据,快照对比天然全覆盖。
    private func notifyChanges() {
        guard transitionObserver != nil || tokenObserver != nil else { return }
        var alive = Set<String>()
        for session in sessions {
            alive.insert(session.id)
            observedMeta[session.id] = (session.kind, session.projectName)
            if observedStates[session.id] != session.state {
                observedStates[session.id] = session.state
                transitionObserver?(session.id, session.kind, session.projectName, session.state)
            }
            if let tokens = session.metrics?.totalTokens, observedTokens[session.id] != tokens {
                observedTokens[session.id] = tokens
                tokenObserver?(session.id, session.kind, tokens)
            }
        }
        for (id, _) in observedStates where !alive.contains(id) {
            if let meta = observedMeta[id] {
                transitionObserver?(id, meta.kind, meta.project, nil)
            }
            observedStates[id] = nil
            observedTokens[id] = nil
            observedMeta[id] = nil
        }
    }

    /// 账号级限额(展开面板顶部展示)
    public var claudeRateLimits: RateLimits?
    public var codexRateLimits: RateLimits?
    public var cursorUsage: CursorUsage?
    /// Cursor 用量拉取失败原因(有用量数据时清空)
    public var cursorUsageError: String?

    /// 等待用户 Yes/No 的权限审批请求
    public struct PendingApproval: Identifiable {
        public let id: UUID
        public let sessionId: String
        public let toolName: String?
        public let detail: String?
        public let createdAt: Date
        public let respond: @Sendable (Bool) -> Void

        public init(sessionId: String, toolName: String?, detail: String?,
                    createdAt: Date = Date(), respond: @escaping @Sendable (Bool) -> Void) {
            self.id = UUID()
            self.sessionId = sessionId
            self.toolName = toolName
            self.detail = detail
            self.createdAt = createdAt
            self.respond = respond
        }
    }

    public private(set) var approvals: [PendingApproval] = []

    public func addApproval(_ approval: PendingApproval) {
        approvals.append(approval)
        // 会话同步进入等待审批态
        if let i = sessions.firstIndex(where: { $0.id == approval.sessionId }) {
            sessions[i].state = .waitingApproval
            sessions[i].lastActivity = approval.createdAt
        }
        notifyChanges()
    }

    public func approval(for sessionId: String) -> PendingApproval? {
        approvals.first { $0.sessionId == sessionId }
    }

    public func resolveApproval(id: UUID, allow: Bool) {
        guard let i = approvals.firstIndex(where: { $0.id == id }) else { return }
        let approval = approvals.remove(at: i)
        approval.respond(allow)
        if let j = sessions.firstIndex(where: { $0.id == approval.sessionId }),
           approvals.allSatisfy({ $0.sessionId != approval.sessionId }) {
            sessions[j].state = .thinking
            sessions[j].lastActivity = Date()
        }
        notifyChanges()
    }

    public init() {}

    public func apply(_ result: IngestResult) {
        switch result {
        case .ignored:
            return
        case .event(let event):
            // 隐藏目录下的后台工具会话(如 claude-mem observer)不展示
            if let cwd = event.cwd, SessionBackfillScanner.isHiddenPath(cwd) { return }
            // 未注册的 claude 会话(后台子 agent)不展示
            if event.kind == .claudeCode,
               let validator = claudeSessionValidator, !validator(event.sessionId) { return }
            // Cursor 子 agent 会话不展示
            if event.kind == .cursor,
               let validator = cursorSessionValidator, !validator(event.sessionId) { return }
            var session = sessions.first(where: { $0.id == event.sessionId })
                ?? AgentSession(
                    id: event.sessionId, kind: event.kind,
                    projectName: Self.projectName(from: event.cwd),
                    cwd: event.cwd ?? "", state: .idle)
            if let cwd = event.cwd, !cwd.isEmpty {
                session.cwd = cwd
                session.projectName = Self.projectName(from: cwd)
            }
            if let app = event.appPath { session.appPath = app }
            if let model = event.model {
                var m = session.metrics ?? Metrics()
                m.model = model
                session.metrics = m
            }
            session.state = mapEventToState(event, current: session.state)
            session.recentEvents.append(event)
            if session.recentEvents.count > Self.maxRecentEvents {
                session.recentEvents.removeFirst(session.recentEvents.count - Self.maxRecentEvents)
            }
            session.lastActivity = event.timestamp
            upsert(session)
            recordToolCallIfNeeded(event)
        case .metrics(let sessionId, let kind, let metrics, let limits):
            if let limits {
                switch kind {
                case .claudeCode: claudeRateLimits = (claudeRateLimits ?? limits).merging(limits)
                case .codex: codexRateLimits = (codexRateLimits ?? limits).merging(limits)
                case .cursor: break
                }
            }
            guard var session = sessions.first(where: { $0.id == sessionId }) else { return }
            // 按字段合并:各来源只带部分字段(codex token_count 无 model,cursor hook 只有 model)
            var merged = session.metrics ?? Metrics()
            if let v = metrics.model { merged.model = v }
            if let v = metrics.contextPct { merged.contextPct = v }
            if let v = metrics.totalTokens { merged.totalTokens = v }
            if let v = metrics.costUSD { merged.costUSD = v }
            session.metrics = merged
            session.lastActivity = Date()
            upsert(session)
        }
        notifyChanges()
    }

    /// 回填磁盘扫描到的会话:不存在则插入;已存在但磁盘更新(transcript 有新写入)
    /// 时刷新活跃时间/指标。明确的 done/approval 可修正旧状态,普通 waiting 不覆盖实时运行态。
    public func backfill(_ scanned: [AgentSession], now: Date = Date()) {
        // 注册表变化时(子 agent 结束、会话退出),清掉已不合法的 claude 会话
        if let validator = claudeSessionValidator {
            sessions.removeAll { $0.kind == .claudeCode && !validator($0.id) }
        }
        if let validator = cursorSessionValidator {
            sessions.removeAll { $0.kind == .cursor && !validator($0.id) }
        }
        for candidate in scanned {
            if candidate.kind == .claudeCode,
               let validator = claudeSessionValidator, !validator(candidate.id) { continue }
            if candidate.kind == .cursor,
               let validator = cursorSessionValidator, !validator(candidate.id) { continue }
            if let i = sessions.firstIndex(where: { $0.id == candidate.id }) {
                let blocksCursorDone =
                    candidate.kind == .cursor && candidate.state == .done
                    && cursorHasActiveSubagents?(candidate.id) == true
                if sessions[i].appPath == nil, let app = candidate.appPath {
                    sessions[i].appPath = app
                }
                // tailer 只有文件名没有 cwd,由磁盘扫描/SQLite 的候选补上
                if sessions[i].cwd.isEmpty, !candidate.cwd.isEmpty {
                    sessions[i].cwd = candidate.cwd
                    sessions[i].projectName = candidate.projectName
                }
                if candidate.lastActivity > sessions[i].lastActivity {
                    // 活跃子任务期间不推进 Cursor done 候选的基准时间；子任务结束后
                    // 同一候选仍保持 newer，下一轮即可恢复正常终态采纳。
                    if let m = candidate.metrics { sessions[i].metrics = m }
                    if !blocksCursorDone {
                        // 磁盘比内存新:会话在别处有了新动静,刷新活跃时间和状态
                        sessions[i].lastActivity = candidate.lastActivity
                        if shouldAdoptBackfillState(
                            current: sessions[i].state, candidate: candidate.state) {
                            sessions[i].state = candidate.state
                        }
                    }
                } else if let cm = candidate.metrics {
                    // 内存较新:不整体覆盖,只补上事件流拿不到的缺失字段
                    // (如 Cursor hook 只带模型名,ctx%/tokens 只在磁盘状态库里)
                    var m = sessions[i].metrics ?? Metrics()
                    if m.model == nil { m.model = cm.model }
                    if m.contextPct == nil { m.contextPct = cm.contextPct }
                    if m.totalTokens == nil { m.totalTokens = cm.totalTokens }
                    if m.costUSD == nil { m.costUSD = cm.costUSD }
                    sessions[i].metrics = m
                }
                // 磁盘无新动静时只允许终态修正(done/审批)。活跃态不采纳,
                // 否则被 prune 判为 disconnected 的僵尸会话会被每轮回填复活成 thinking。
                if candidate.lastActivity == sessions[i].lastActivity,
                   candidate.state == .done || candidate.state == .waitingApproval {
                    // Cursor:相等时间的终态来自状态库/transcript 尾部推断,不能压过实时
                    // 运行/等待态——子任务仍在跑时父会话的主 transcript 可能已 turn_ended,
                    // 若采纳会误判 done。只有 candidate 时间更新时(上面的分支)才采纳终态。
                    let liveStates: Set<SessionState> =
                        [.thinking, .runningTool, .waitingInput, .waitingApproval]
                    if !blocksCursorDone
                        && !(candidate.kind == .cursor && liveStates.contains(sessions[i].state)) {
                        sessions[i].state = candidate.state
                    }
                }
            } else {
                var fresh = candidate
                // 插入即适用断连规则,避免长时间没动静的会话以 thinking 挂在「进行中」
                if now.timeIntervalSince(fresh.lastActivity) > disconnectAfter {
                    fresh.state = .disconnected
                }
                sessions.append(fresh)
            }
        }
        // CLI 已退出的 codex 会话不能继续标「等你」:SQLite/rollout 都不记录进程死亡,
        // 只能靠进程表反查。只收敛等待类状态;活跃态有实时事件兜着,避免与桌面端线程互相打架。
        if let isAlive = codexLivenessCheck {
            for i in sessions.indices where sessions[i].kind == .codex {
                switch sessions[i].state {
                case .idle, .waitingInput, .waitingApproval:
                    if !isAlive(sessions[i]) { sessions[i].state = .done }
                default:
                    break
                }
            }
        }
        sessions.sort { $0.lastActivity > $1.lastActivity }
        notifyChanges()
    }

    /// 权威状态覆盖:来源比事件流更可信时使用(如 Claude 注册表的实时 status,
    /// 在 hooks 不可用时它是 Claude Code 自己上报的唯一真状态)。不影响活跃时间。
    public func applyAuthoritativeState(id: String, state: SessionState) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[i].state = state
        notifyChanges()
    }

    public func prune(now: Date = Date()) {
        // 客户端 50s 就放弃等待了,过期的审批请求按钮没有意义
        approvals.removeAll { now.timeIntervalSince($0.createdAt) > 50 }
        sessions.removeAll { now.timeIntervalSince($0.lastActivity) > removeAfter }
        for i in sessions.indices
        where now.timeIntervalSince(sessions[i].lastActivity) > disconnectAfter {
            sessions[i].state = .disconnected
        }
        notifyChanges()
    }

    private func upsert(_ session: AgentSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        sessions.sort { $0.lastActivity > $1.lastActivity }
    }

    private func shouldAdoptBackfillState(current: SessionState, candidate: SessionState) -> Bool {
        switch candidate {
        case .done, .waitingApproval:
            return true
        case .thinking, .runningTool:
            return current == .idle || current == .waitingInput || current == .disconnected
        case .waitingInput:
            return current == .disconnected
        case .idle, .disconnected:
            return false
        }
    }

    private static let toolBeginEvents: Set<String> = [
        "PreToolUse", "preToolUse", "function_call", "custom_tool_call",
        "web_search_call", "tool_search_call",
        "exec_command_begin", "patch_apply_begin", "mcp_tool_call_begin"
    ]

    private static let toolEndEvents: Set<String> = [
        "PostToolUse", "PostToolUseFailure", "postToolUse",
        "function_call_output", "custom_tool_call_output", "tool_search_output",
        "web_search_end", "exec_command_end", "mcp_tool_call_end", "patch_apply_end"
    ]

    private func recordToolCallIfNeeded(_ event: AgentEvent) {
        guard let observer = toolCallObserver else { return }

        if Self.toolEndEvents.contains(event.name) {
            let key = thirdPartyKey(event) ?? openThirdPartyTool[event.sessionId]?.key
            guard let key else { return }
            openThirdPartyTool[event.sessionId] = nil
            observer(event.sessionId, event.kind, key, event.tool ?? event.detail,
                     .end, event.timestamp)
            return
        }

        guard Self.toolBeginEvents.contains(event.name),
              let key = thirdPartyKey(event) else { return }
        let raw = event.tool ?? event.detail
        // 3 秒内同 key 去重:假会话 keepalive / 重复 hook 不虚增次数
        if let prev = openThirdPartyTool[event.sessionId],
           prev.key == key,
           event.timestamp.timeIntervalSince(prev.at) < 3 {
            return
        }
        openThirdPartyTool[event.sessionId] = (key, event.timestamp)
        observer(event.sessionId, event.kind, key, raw, .begin, event.timestamp)
    }

    /// 只统计第三方/MCP；内置 Read/Bash 等不入库存用量
    private func thirdPartyKey(_ event: AgentEvent) -> String? {
        if let label = ThirdPartyToolDisplay.label(tool: event.tool, detail: event.detail) {
            return label
        }
        guard let tool = event.tool else { return nil }
        switch tool {
        case "CallMcpTool", "FetchMcpResource", "ListMcpResources", "GetMcpTools":
            return event.detail ?? tool
        default:
            return nil
        }
    }

    static func projectName(from cwd: String?) -> String {
        guard let cwd, !cwd.isEmpty else { return "unknown" }
        return (cwd as NSString).lastPathComponent
    }
}
