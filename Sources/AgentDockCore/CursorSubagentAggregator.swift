import Foundation

/// 把 Cursor 子 agent(Task/best-of-N 派生)的 transcript 行聚合成「父会话正在跑子任务」
/// 的进度信号。子 agent 自己不作为独立用户会话展示,但父会话应显示它派发的 Task 仍在执行。
///
/// 输入:父/子会话 id、cwd,以及子 transcript 的一行或原生 subagent hook。
/// 输出面向父会话的 Cursor 事件:
/// - 任何非终态子事件 → `subagentProgress`(tool=`Task`,detail 展示运行中子任务数)
/// - 有子任务结束但仍有在跑 → 依旧 `subagentProgress`(计数递减)
/// - 最后一个子任务结束 → `subagentComplete`(父会话回到 thinking)
/// - 无法解析的行 → `.ignored`,不改动活跃集合
///
/// ## 身份关联(避免幻影子任务)
/// 官方 hook 在**父会话上下文**触发:`subagentStart/Stop` 的 `subagent_id` 实为父 Task 的
/// `tool_call_id`,而子 transcript 的 tailer 用的是子会话 uuid(路径 stem)——同一逻辑子任务
/// 会以不同 id 出现。因此每个 canonical child 维护一组**别名**(tool_call_id + 路径 stem +
/// 子 conversation id 等),start 时全部登记,任一别名的进度/终态都归到同一 child。
///
/// ## 绝不永久挂起
/// - stop 带明确 child id 但不匹配(tailer 启动边界/旧文件)→ 忽略,保护在跑子任务。
/// - stop 无任何 child id 但 parent 可知 → 按 FIFO 安全释放最老的一个(聚合只需要计数)。
/// - 连 parent 都未知 → 忽略,依赖 TTL。
/// - subagent transcript 常无终态(0 个 turn_ended)、hook 也可能丢 stop:短于 2h 的
///   stale 超时回收 child,让父会话不永久卡 running;父终态被 defer 时同样在回收后放出。
///
/// 仅在主线程访问(AppDelegate 持有),不做并发保护。
@MainActor
public final class CursorSubagentAggregator {
    /// 单个逻辑子任务:一组跨通道别名 + 生命周期时间戳。
    private struct Child {
        var aliases: Set<String>
        let firstSeen: Date
        var updatedAt: Date
        /// 是否见过原生 hook 信号:见过则其 transcript turn_ended 需去抖等 subagentStop。
        var sawHook: Bool
        /// transcript turn_ended 的试探性终态时间(去抖中);nil 表示未处于试探终态。
        var tentativeStopAt: Date?
    }

    private struct ParentState {
        /// 按插入顺序保存,索引即 FIFO 年龄。
        var children: [Child]
        var pendingTerminal: String?
        var updatedAt: Date
    }

    private var parents: [String: ParentState] = [:]
    private let childStaleTimeout: TimeInterval
    private let transcriptStopDebounce: TimeInterval

    public init(childStaleTimeout: TimeInterval = 30 * 60,
                transcriptStopDebounce: TimeInterval = 5) {
        self.childStaleTimeout = childStaleTimeout
        self.transcriptStopDebounce = transcriptStopDebounce
    }

    /// 子 agent transcript 的终态事件名(该子任务本回合结束)。
    private static let terminalEvents: Set<String> = ["stop", "sessionEnd"]

    public func hasActiveChildren(parentId: String) -> Bool {
        parents[parentId]?.children.isEmpty == false
    }

    /// 父终态早于子任务终态时暂存；最后一个 child 结束后再输出。
    public func deferParentTerminal(
        parentId: String, eventName: String, at: Date = Date()
    ) {
        guard var state = parents[parentId], !state.children.isEmpty,
              Self.terminalEvents.contains(eventName) else { return }
        state.pendingTerminal = eventName
        state.updatedAt = at
        parents[parentId] = state
    }

    public func ingest(
        parentId: String, childId: String, cwd: String?, line: Data, at: Date = Date()
    ) -> IngestResult {
        // 复用 transcript 解析:子行与主行同格式,只是归属到父会话
        guard case .event(let childEvent) =
                EventIngestor.parseCursorTranscriptLine(sessionId: childId, cwd: cwd, line: line)
        else { return .ignored }
        let aliases: Set<String> = childId.isEmpty ? [] : [childId]
        if Self.terminalEvents.contains(childEvent.name) {
            return resolveTerminal(parentId: parentId, aliases: aliases,
                                   source: .transcript, cwd: cwd, at: at)
        }
        return resolveProgress(parentId: parentId, aliases: aliases,
                               sawHook: false, cwd: cwd, at: at)
    }

    /// Cursor 官方 subagentStart/subagentStop hook 与 transcript 共用同一活跃集合。
    /// `aliases` 承载 subagent_id 之外的额外身份(如 agent_transcript_path 的 stem)。
    public func ingestHook(
        parentId: String, childId: String, eventName: String,
        cwd: String?, at: Date = Date(), aliases: [String] = []
    ) -> IngestResult {
        let effective = Set(([childId] + aliases).filter { !$0.isEmpty })
        switch eventName {
        case "subagentStart":
            return resolveProgress(parentId: parentId, aliases: effective,
                                   sawHook: true, cwd: cwd, at: at)
        case "subagentStop":
            return resolveTerminal(parentId: parentId, aliases: effective,
                                   source: .hook, cwd: cwd, at: at)
        default:
            return .ignored
        }
    }

    /// 权威父 sessionEnd 或其他生命周期清理使用。
    public func reset(parentId: String) {
        parents[parentId] = nil
    }

    /// 清理 tailer 丢终态等异常留下的活跃集合,避免常驻 App 内存无限增长,并回收:
    /// - 超过 stale 超时的 child(短于整体 maxIdle);
    /// - 去抖窗口已过、始终未等到 subagentStop 的试探性 transcript 终态。
    /// 回收导致父任务清空时,发出被 defer 的父终态或专用完成态,防止父会话永久挂起。
    @discardableResult
    public func prune(now: Date = Date(), maxIdle: TimeInterval = 2 * 60 * 60) -> [IngestResult] {
        var results: [IngestResult] = []
        for (parentId, state) in parents {
            // 整段过期:父级本身长时间无任何动静,直接丢弃(有界内存)。
            if now.timeIntervalSince(state.updatedAt) > maxIdle {
                parents[parentId] = nil
                continue
            }
            var mutated = state
            let before = mutated.children.count
            mutated.children.removeAll { child in
                if now.timeIntervalSince(child.updatedAt) > childStaleTimeout { return true }
                if let stopAt = child.tentativeStopAt,
                   now.timeIntervalSince(stopAt) > transcriptStopDebounce { return true }
                return false
            }
            guard mutated.children.count != before else { continue }
            if mutated.children.isEmpty {
                parents[parentId] = nil
                results.append(.event(finishEvent(parentId: parentId,
                                                  pendingTerminal: mutated.pendingTerminal,
                                                  cwd: nil)))
            } else {
                parents[parentId] = mutated
                results.append(.event(progressEvent(parentId: parentId,
                                                    count: mutated.children.count, cwd: nil)))
            }
        }
        return results
    }

    private enum TerminalSource { case hook, transcript }

    private func resolveProgress(
        parentId: String, aliases: Set<String>, sawHook: Bool, cwd: String?, at: Date
    ) -> IngestResult {
        guard !aliases.isEmpty else { return .ignored }
        var state = parents[parentId] ?? ParentState(children: [], pendingTerminal: nil, updatedAt: at)
        if let idx = state.children.firstIndex(where: { !$0.aliases.isDisjoint(with: aliases) }) {
            state.children[idx].aliases.formUnion(aliases)
            state.children[idx].updatedAt = at
            state.children[idx].tentativeStopAt = nil  // 有新活动 → 撤销试探性终态(去抖复活)
            if sawHook { state.children[idx].sawHook = true }
        } else {
            state.children.append(Child(aliases: aliases, firstSeen: at, updatedAt: at,
                                        sawHook: sawHook, tentativeStopAt: nil))
        }
        state.updatedAt = at
        parents[parentId] = state
        return .event(progressEvent(parentId: parentId, count: state.children.count, cwd: cwd))
    }

    private func resolveTerminal(
        parentId: String, aliases: Set<String>, source: TerminalSource, cwd: String?, at: Date
    ) -> IngestResult {
        guard var state = parents[parentId], !state.children.isEmpty else { return .ignored }

        let matchIdx = aliases.isEmpty
            ? nil
            : state.children.firstIndex(where: { !$0.aliases.isDisjoint(with: aliases) })

        guard let idx = matchIdx else {
            // 带明确 id 却不匹配 → tailer 启动边界/旧文件,忽略,保护在跑子任务。
            guard aliases.isEmpty else { return .ignored }
            // 匿名终态 + parent 可知 → FIFO 释放最老的一个(聚合只需计数)。
            state.children.removeFirst()
            return finalize(parentId: parentId, state: &state, cwd: cwd, at: at)
        }

        let isLast = state.children.count == 1
        if source == .transcript && isLast && state.children[idx].sawHook {
            // 唯一 hook child 的 transcript turn_ended:去抖,优先等权威 subagentStop,
            // 期间保持运行中,避免父 running↔thinking 抖动。
            state.children[idx].tentativeStopAt = at
            state.children[idx].updatedAt = at
            state.updatedAt = at
            parents[parentId] = state
            return .event(progressEvent(parentId: parentId, count: state.children.count, cwd: cwd))
        }

        state.children.remove(at: idx)
        return finalize(parentId: parentId, state: &state, cwd: cwd, at: at)
    }

    /// 移除 child 后收敛父状态:空 → 完成/放出 defer 终态;非空 → 进度。
    private func finalize(
        parentId: String, state: inout ParentState, cwd: String?, at: Date
    ) -> IngestResult {
        state.updatedAt = at
        if state.children.isEmpty {
            parents[parentId] = nil
            return .event(finishEvent(parentId: parentId,
                                      pendingTerminal: state.pendingTerminal, cwd: cwd))
        }
        parents[parentId] = state
        return .event(progressEvent(parentId: parentId, count: state.children.count, cwd: cwd))
    }

    private func finishEvent(parentId: String, pendingTerminal: String?, cwd: String?) -> AgentEvent {
        if let terminal = pendingTerminal {
            return AgentEvent(sessionId: parentId, kind: .cursor, cwd: cwd, name: terminal)
        }
        // 所有子任务结束且父终态尚未到达:使用专用终态,避免伪造通用 tool end。
        return AgentEvent(sessionId: parentId, kind: .cursor, cwd: cwd,
                          name: "subagentComplete", detail: "Task", tool: "Task")
    }

    private func progressEvent(parentId: String, count: Int, cwd: String?) -> AgentEvent {
        AgentEvent(sessionId: parentId, kind: .cursor, cwd: cwd,
                   name: "subagentProgress",
                   detail: SubagentDisplay.progressDetail(count: count), tool: "Task")
    }
}
