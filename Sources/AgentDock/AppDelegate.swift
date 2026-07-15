import AppKit
import SwiftUI
import Carbon.HIToolbox
import AgentDockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SessionStore()
    private var server: SocketServer?
    private var codexTailer: CodexSessionTailer?
    private var cursorTailer: CodexSessionTailer?
    private var notchWindow: NotchWindow?
    private var pruneTimer: Timer?
    private var codexLimitsTimer: Timer?
    private var statusItem: NSStatusItem?
    /// 菜单栏模式:运行中眨眼
    private var statusBlinkTimer: Timer?
    private var statusEyesOpen = true
    private let hotkeys = HotkeyManager()
    private var toggleHotkeyId: UInt32 = 0
    private var approvalHotkeyIds: [UInt32] = []
    private let keepAwake = KeepAwake()

    static let home = NSHomeDirectory()
    static let socketPath = home + "/.agentdock/agentdock.sock"
    static let emitInstallPath = home + "/.agentdock/agentdock-emit"
    /// 活动历史库(工作时长/token 消耗/等待统计)
    static let history = HistoryStore(path: home + "/.agentdock/history.sqlite")

    private let claudeRegistry = ClaudeSessionRegistry(dir: home + "/.claude/sessions")
    private var allowedClaudeIds: Set<String> = []

    /// 存活 codex 进程的 cwd → 宿主 App,每轮 backfill 刷新
    private var codexLiveHosts: [String: String] = [:]
    /// Cursor 的子 agent 会话 id(Task/best-of-N 派生),每轮 backfill 刷新 + 点查缓存
    private var cursorSubagentIds: Set<String> = []
    /// 已确认是用户主会话的 id(点查结果缓存,避免重复开库)
    private var cursorKnownMainIds: Set<String> = []
    /// 已注入过「向你提问」事件的 bubble,避免每轮重复触发
    private var seenQuestionBubbles: Set<String> = []
    /// 挂起中的交互卡片(bubbleId → 会话与类型):由高频监视器秒级检测处理结果
    private var watchedInteractions: [String: (sessionId: String, kind: CursorStateReader.PendingInteractionKind)] = [:]
    private var interactionWatchTimer: Timer?
    /// 新卡片的快速探测(2s):等 10s 回填才发现「需要你审批」体感太慢
    private var fastInteractionTimer: Timer?
    private var fastProbeInFlight = false

    // MARK: 通道优先级(三家同一套机制:主通道健康则次级让位,过期自动降级)
    //
    // Cursor:  1.hooks(亚秒) → 2.transcript tailer(秒级) → 3.bubble 探测(10s) → 4.回填(10s)
    // Claude:  1.hooks(亚秒) → 2.注册表 status(10s,Claude 自报的权威状态) → 3.transcript 回填(10s)
    // Codex:   1.rollout tailer + notify(秒级) → 2.SQLite 尾部推断(10s,天然幂等,常开兜底)
    //
    // 健康判定不猜版本,以事实为准:收到主通道事件即健康(2 分钟信任窗口)。
    // 本版 Cursor 的 hooks 是坏的,哪个版本修好了,App 不用改动自动升级。

    private static let channelTrustWindow: TimeInterval = 120
    /// 最近一次收到各家主通道事件的时间
    private var lastCursorHookAt: Date = .distantPast
    private var lastClaudeHookAt: Date = .distantPast
    private var cursorHooksHealthy: Bool {
        Date().timeIntervalSince(lastCursorHookAt) < Self.channelTrustWindow
    }
    private var claudeHooksHealthy: Bool {
        Date().timeIntervalSince(lastClaudeHookAt) < Self.channelTrustWindow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        allowedClaudeIds = claudeRegistry.allowedSessionIds()
        store.claudeSessionValidator = { [weak self] id in
            guard let self else { return true }
            // 本地 UI 演示会话(scripts/fake-session.sh)不走 Claude 注册表
            if id.hasPrefix("agentdock-demo") { return true }
            if self.allowedClaudeIds.contains(id) { return true }
            // 未知 id 可能是刚开的新会话:立刻重扫一次注册表再判
            self.allowedClaudeIds = self.claudeRegistry.allowedSessionIds()
            return self.allowedClaudeIds.contains(id)
        }
        store.codexLivenessCheck = { [weak self] session in
            guard let self, !session.cwd.isEmpty else { return true }
            return self.codexLiveHosts[session.cwd] != nil
        }
        store.cursorSessionValidator = { [weak self] id in
            guard let self else { return true }
            if self.cursorSubagentIds.contains(id) { return false }
            if self.cursorKnownMainIds.contains(id) { return true }
            // 未知 id:名单可能还没刷新(hooks 事件比 10s 回填快),当场点查状态库
            switch CursorStateReader.isSubagentConversation(
                dbPath: CursorStateReader.defaultDatabasePath(), conversationId: id) {
            case .some(true):
                self.cursorSubagentIds.insert(id)
                return false
            case .some(false):
                self.cursorKnownMainIds.insert(id)
                return true
            case .none:
                return true  // 库里还没记录(会话刚创建):暂放行,回填名单会兜底清理
            }
        }
        // 活动历史:状态区间与 token 采样落库(HistoryStore 内部异步,不阻塞)
        store.transitionObserver = { sessionId, kind, project, newState in
            Self.history.recordTransition(sessionId: sessionId, kind: kind,
                                          project: project, to: newState)
        }
        store.tokenObserver = { sessionId, kind, tokens in
            Self.history.recordTokens(sessionId: sessionId, kind: kind, tokens: tokens)
        }
        store.toolCallObserver = { sessionId, kind, toolKey, toolRaw, phase, at in
            switch phase {
            case .begin:
                Self.history.recordToolCallBegin(sessionId: sessionId, kind: kind,
                                                 toolKey: toolKey, toolRaw: toolRaw, at: at)
            case .end:
                Self.history.recordToolCallEnd(sessionId: sessionId, toolKey: toolKey, at: at)
            }
        }
        installEmitScript()
        startServer()
        startCodexTailer()
        startCursorTailer()
        setupStatusItem()

        notchWindow = NotchWindow(store: store, settings: AppSettings.shared)  // hover 由窗口层监听驱动
        // 展开面板 = 用户正在看数据:限额若不够新鲜(>30s)立刻补一次探测,
        // 覆盖「客户端重置额度后没有任务在跑」这类两次轮询间隙里的变化
        notchWindow?.onHoverBegan = { [weak self] in self?.pollAccountUsage(minInterval: 30) }
        notchWindow?.statusButton = statusItem?.button
        notchWindow?.show()
        setupHotkeys()
        NotificationCenter.default.addObserver(
            forName: .agentDockOpenSettings, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.openSettings() }
        }
        NotificationCenter.default.addObserver(
            forName: .agentDockDisplayChanged, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.notchWindow?.reposition() }
        }
        NotificationCenter.default.addObserver(
            forName: .agentDockPlacementChanged, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                // 切换挂靠位置时保持面板打开(用户多半在设置页操作),只重定位
                self?.notchWindow?.hoverState.hovering = false
                self?.notchWindow?.hoverState.pinnedOpen = true
                self?.notchWindow?.reposition()
                self?.refreshStatusItem()
            }
        }
        observeStatusItem()
        refreshStatusItem()
        NotificationCenter.default.addObserver(
            forName: .agentDockHotkeysChanged, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.reloadHotkeys() }
        }
        NotificationCenter.default.addObserver(
            forName: .agentDockKeepAwakeChanged, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.syncKeepAwake() }
        }
        observeKeepAwake()
        syncKeepAwake()
        // 快捷键录制期间暂停全局热键(否则按下的组合会被热键吞掉),并给面板键盘焦点
        NotificationCenter.default.addObserver(
            forName: .agentDockHotkeyRecordingBegan, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hotkeys.unregister(self.toggleHotkeyId)
                self.approvalHotkeyIds.forEach { self.hotkeys.unregister($0) }
                self.approvalHotkeyIds = []
                self.notchWindow?.makeKeyForTyping()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .agentDockHotkeyRecordingEnded, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.reloadHotkeys() }
        }
        // 用量页手动刷新:立即探测三家账号用量 + 跑一轮回填(cursor/claude 指标)
        NotificationCenter.default.addObserver(
            forName: .agentDockRefreshUsage, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                self?.pollAccountUsage()
                self?.backfillSessions()
            }
        }

        seedClaudeLimitsFromLastStatusline()
        backfillSessions()
        // 10s 一轮:全量扫描实测稳态约 70ms 且在后台线程执行,主线程只做数据应用
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.prune()
                self?.backfillSessions()
            }
        }
        fastInteractionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fastProbePendingInteractions() }
        }
        pollAccountUsage()
        codexLimitsTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollAccountUsage() }
        }
        // 首次启动:弹出分步设置向导(拖拽安装后首次打开 App 时)
        SetupWizard.showIfNeeded()
        // 匿名遥测:崩溃 handler + 每日一次启动活跃(不采集会话/路径/token)
        Telemetry.installCrashReporting(appVersion: AppInfo.version)
        Telemetry.recordLaunch(appVersion: AppInfo.version)
    }

    /// Claude 限额只随 statusline 事件到达,App 重启会丢;emit 脚本每次都会把
    /// statusline 原样落盘,启动时回放最后一份,限额(若带)就能立刻恢复。
    /// 新鲜度以文件 mtime 为准,不冒充「刚更新」。
    private func seedClaudeLimitsFromLastStatusline() {
        let path = Self.home + "/.agentdock/last-statusline.json"
        guard let payload = FileManager.default.contents(atPath: path), !payload.isEmpty else { return }
        var envelope = Data(#"{"source":"claude-code","type":"statusline","payload":"#.utf8)
        envelope.append(payload)
        envelope.append(Data("}".utf8))
        let result = EventIngestor.parseLine(envelope)
        store.apply(result)
        if case .metrics(_, _, _, .some(let limits)) = result,
           let mtime = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date {
            store.claudeRateLimits = RateLimits(fiveHourPct: limits.fiveHourPct,
                                                sevenDayPct: limits.sevenDayPct,
                                                updatedAt: mtime)
        }
    }

    private var lastCodexLimitsFetchAt: Date = .distantPast

    // MARK: - 全局快捷键

    /// 面板切换键常驻;允许/拒绝只在有待审批时注册(避免长期霸占系统级按键)
    private func setupHotkeys() {
        let toggle = AppSettings.shared.toggleHotkey
        toggleHotkeyId = hotkeys.register(keyCode: toggle.keyCode, modifiers: toggle.modifiers) { [weak self] in
            self?.notchWindow?.togglePinned()
        }
        observeApprovals()
    }

    /// 设置里改了快捷键:全部注销重挂
    private func reloadHotkeys() {
        hotkeys.unregister(toggleHotkeyId)
        approvalHotkeyIds.forEach { hotkeys.unregister($0) }
        approvalHotkeyIds = []
        let toggle = AppSettings.shared.toggleHotkey
        toggleHotkeyId = hotkeys.register(keyCode: toggle.keyCode, modifiers: toggle.modifiers) { [weak self] in
            self?.notchWindow?.togglePinned()
        }
        syncApprovalHotkeys()
    }

    /// 持续观察审批队列/会话审批态变化,动态注册/注销允许/拒绝快捷键;
    /// 菜单栏模式下「等你处理」也要自动弹出面板
    private func observeApprovals() {
        withObservationTracking {
            _ = store.approvals.count
            _ = store.sessions.filter {
                $0.state == .waitingApproval || $0.state == .waitingInput
            }.count
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.syncApprovalHotkeys()
                self?.notchWindow?.refreshVisibility()
                self?.observeApprovals()
            }
        }
    }

    /// 有辅助代答能力的待审批会话(Codex/Cursor)
    private var firstAssistedApprovalSession: AgentSession? {
        store.sessions.first { $0.state == .waitingApproval && AssistedApproval.supports($0.kind) }
    }

    private func syncApprovalHotkeys() {
        let hasPending = !store.approvals.isEmpty || firstAssistedApprovalSession != nil
        if hasPending, approvalHotkeyIds.isEmpty {
            let allow = AppSettings.shared.allowHotkey
            let deny = AppSettings.shared.denyHotkey
            approvalHotkeyIds = [
                hotkeys.register(keyCode: allow.keyCode, modifiers: allow.modifiers) { [weak self] in
                    self?.respondFirstApproval(allow: true)
                },
                hotkeys.register(keyCode: deny.keyCode, modifiers: deny.modifiers) { [weak self] in
                    self?.respondFirstApproval(allow: false)
                },
            ]
        } else if !hasPending, !approvalHotkeyIds.isEmpty {
            approvalHotkeyIds.forEach { hotkeys.unregister($0) }
            approvalHotkeyIds = []
        }
    }

    // MARK: - 防休眠(agent 任务进行中保持清醒)

    /// 持续观察「是否有进行中的任务」,变化时同步电源断言
    private func observeKeepAwake() {
        withObservationTracking {
            _ = store.sessions.filter { $0.state.isActive }.count
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.syncKeepAwake()
                self?.observeKeepAwake()
            }
        }
    }

    private func syncKeepAwake() {
        let hasActive = store.sessions.contains { $0.state.isActive }
        keepAwake.setActive(AppSettings.shared.keepAwakeWhileRunning && hasActive)
    }

    private func respondFirstApproval(allow: Bool) {
        // Claude 的 hook 阻塞代答优先;其次 Codex/Cursor 辅助代答
        if let approval = store.approvals.first {
            store.resolveApproval(id: approval.id, allow: allow)
        } else if let session = firstAssistedApprovalSession {
            AssistedApproval.respond(session: session, allow: allow)
        }
    }

    // MARK: - 挂起交互监视器(秒级)
    //
    // 提问/审批卡片被用户处理后没有任何即时信号(应答不产生 hook 事件,
    // transcript 延迟落盘),10s 回填粒度太粗。有卡片挂起时启动 1s 定时器,
    // 只对挂起的 bubble 做主键点查(毫秒级),处理完立即解除等待态并停表。

    /// 新发现的提问/审批卡片:注入事件让会话进入等待态,并交给秒级监视器盯处理结果
    private func handlePendingInteractions(_ interactions: [CursorStateReader.PendingInteraction]) {
        for interaction in interactions {
            switch interaction.kind {
            case .question:
                guard !seenQuestionBubbles.contains(interaction.bubbleId) else { continue }
                seenQuestionBubbles.insert(interaction.bubbleId)
                store.apply(.event(AgentEvent(
                    sessionId: interaction.sessionId, kind: .cursor,
                    name: "preToolUse", detail: "AskQuestion", tool: "AskQuestion")))
                watchInteraction(interaction)
            case .approval:
                guard watchedInteractions[interaction.bubbleId] == nil else { continue }
                store.apply(.event(AgentEvent(
                    sessionId: interaction.sessionId, kind: .cursor,
                    name: "approvalRequest", detail: interaction.detail)))
                watchInteraction(interaction)
            }
        }
    }

    /// 快速探测(2s):只对「进行中的 Cursor 会话」做挂起卡片点查,
    /// 把「需要你审批」的发现延迟从 10s 回填压到 2s 内。查询本身是毫秒级主键范围扫描。
    private func fastProbePendingInteractions() {
        guard !fastProbeInFlight else { return }
        let activeIds = store.sessions
            .filter { $0.kind == .cursor && $0.state.isActive }
            .map(\.id)
        guard !activeIds.isEmpty else { return }
        fastProbeInFlight = true
        Task.detached(priority: .utility) { [weak self] in
            let interactions = CursorStateReader.pendingInteractions(
                dbPath: CursorStateReader.defaultDatabasePath(), conversationIds: activeIds)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.fastProbeInFlight = false
                self.handlePendingInteractions(interactions)
            }
        }
    }

    private func watchInteraction(_ interaction: CursorStateReader.PendingInteraction) {
        watchedInteractions[interaction.bubbleId] = (interaction.sessionId, interaction.kind)
        guard interactionWatchTimer == nil else { return }
        interactionWatchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkWatchedInteractions() }
        }
    }

    private func checkWatchedInteractions() {
        guard !watchedInteractions.isEmpty else {
            interactionWatchTimer?.invalidate()
            interactionWatchTimer = nil
            return
        }
        let bubbles = watchedInteractions.map { (sessionId: $0.value.sessionId, bubbleId: $0.key) }
        Task.detached(priority: .utility) { [weak self] in
            let resolved = CursorStateReader.resolvedBubbleIds(
                dbPath: CursorStateReader.defaultDatabasePath(), bubbles: bubbles)
            guard !resolved.isEmpty else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for bubbleId in resolved {
                    guard let watched = self.watchedInteractions.removeValue(forKey: bubbleId) else { continue }
                    // 提问已答 → 回到思考;审批已处理 → 解除等待
                    self.store.apply(.event(AgentEvent(
                        sessionId: watched.sessionId, kind: .cursor,
                        name: watched.kind == .question ? "postToolUse" : "approvalResolved")))
                }
                if self.watchedInteractions.isEmpty {
                    self.interactionWatchTimer?.invalidate()
                    self.interactionWatchTimer = nil
                }
            }
        }
    }

    /// 三家账号用量:启动 + 5 分钟定时 + 悬停按需,minInterval 防止频繁悬停反复探测。
    /// 主通道都是各家自己的 OAuth 凭证 + 官方端点(结构化、带重置时间);
    /// Codex 的 app-server 子进程退为 OAuth 不可用时的 fallback(带失败冷却)。
    private func pollAccountUsage(minInterval: TimeInterval = 0) {
        guard Date().timeIntervalSince(lastCodexLimitsFetchAt) >= minInterval else { return }
        lastCodexLimitsFetchAt = Date()
        Task.detached(priority: .utility) { [weak self] in
            var limits = await CodexUsageProber.fetch()
            if limits == nil { limits = CodexRateLimitProber.fetch() }
            guard let limits else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.store.codexRateLimits = (self.store.codexRateLimits ?? limits).merging(limits)
            }
        }
        Task.detached(priority: .utility) { [weak self] in
            guard let limits = await ClaudeUsageProber.fetch() else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.store.claudeRateLimits = (self.store.claudeRateLimits ?? limits).merging(limits)
            }
        }
        Task(priority: .utility) { [weak self] in
            let result = await CursorUsageProber.probe()
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let usage = result.usage {
                    self.store.cursorUsage = usage
                    self.store.cursorUsageError = nil
                } else {
                    // 保留上次成功数据,只更新错误提示
                    self.store.cursorUsageError = result.error
                }
            }
        }
    }

    /// 回填任务在跑时跳过新一轮(10s 周期下防重入)
    private var backfillInFlight = false

    /// 扫描磁盘 transcript,补上「启动前就存在、还没发过事件」的会话(CLI/桌面端/插件)。
    /// 全部 IO 在后台线程,主线程只应用结果。
    private func backfillSessions() {
        guard !backfillInFlight else { return }
        backfillInFlight = true
        let home = Self.home
        let registry = claudeRegistry
        // claude hooks 不可用时,注册表 status 是 Claude 自报的权威状态(次级通道)
        let useClaudeRegistryStatus = !claudeHooksHealthy
        Task.detached(priority: .utility) { [weak self] in
            let registryEntries = registry.allowedEntries()
            // 回填的会话没经过发射脚本,appPath 缺失会导致点击跳不过去、图标退化成
            // 通用 CLI 图标——claude 用注册表 pid、codex 用「cwd 匹配活进程」补齐宿主。
            var claudeHosts: [String: String] = [:]
            for entry in registryEntries {
                if let app = HostAppResolver.appPath(forPid: entry.pid) {
                    claudeHosts[entry.sessionId] = app
                }
            }
            let codexHosts = HostAppResolver.hostAppsByCwd(executablePrefix: "codex")

            var scanned = SessionBackfillScanner.scanClaude(projectsRoot: home + "/.claude/projects")
                + SessionBackfillScanner.scanCodex(root: home + "/.codex/sessions")
                + SessionBackfillScanner.scanCursor(projectsRoot: home + "/.cursor/projects")
            // 新版 Codex 的会话状态在 SQLite 里,JSONL 只是旧版遗留
            if let db = CodexStateReader.findDatabase(codexRoot: home + "/.codex") {
                scanned += CodexStateReader.recentThreads(dbPath: db)
                    .filter { !SessionBackfillScanner.isHiddenPath($0.cwd) }
            }
            // Cursor 的 ctx%/tokens 只在其全局状态库里,transcript/hook 都不带
            let cursorSnapshot = CursorStateReader.recentConversations(
                dbPath: CursorStateReader.defaultDatabasePath())
            scanned += cursorSnapshot.sessions
            // 等用户处理的提问/审批卡片:transcript 延迟落盘,hooks 也没有审批事件,
            // 只能从 bubble 实时探测(始终运行)
            let interactions = CursorStateReader.pendingInteractions(
                dbPath: CursorStateReader.defaultDatabasePath(),
                conversationIds: cursorSnapshot.sessions.map(\.id))
            let resolved = scanned.map { session in
                guard session.appPath == nil else { return session }
                var s = session
                switch s.kind {
                case .claudeCode: s.appPath = claudeHosts[s.id]
                case .codex: s.appPath = codexHosts[s.cwd].flatMap { $0.isEmpty ? nil : $0 }
                case .cursor: break  // UI 兜底 Cursor.app
                }
                return s
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.allowedClaudeIds = Set(registryEntries.map(\.sessionId))
                self.codexLiveHosts = codexHosts
                self.cursorSubagentIds.formUnion(cursorSnapshot.subagentIds)
                self.store.backfill(resolved)
                self.handlePendingInteractions(interactions)
                if useClaudeRegistryStatus {
                    for entry in registryEntries {
                        if let state = entry.sessionState {
                            self.store.applyAuthoritativeState(id: entry.sessionId, state: state)
                        }
                    }
                }
                self.backfillInFlight = false
            }
        }
    }

    /// 无 Dock 图标、无主窗口:用户在启动台/访达再次点击 App 图标时系统发 reopen,
    /// 不处理就毫无反应(看起来像"点不开")——展开面板作为可见反馈
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        notchWindow?.hoverState.pinnedOpen = true
        notchWindow?.refreshVisibility()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        codexTailer?.stop()
        cursorTailer?.stop()
    }

    // MARK: - 采集

    private func startServer() {
        let server = SocketServer(path: Self.socketPath) { line, respond in
            // 权限审批请求需要应答;其余为单向事件流
            if let approval = Self.parseApprovalRequest(line, respond: respond) {
                Task { @MainActor [weak self] in self?.store.addApproval(approval) }
                return
            }
            let result = EventIngestor.parseLine(line)
            Task { @MainActor [weak self] in
                guard let self else { return }
                // 主通道事件到达 = 该家 hooks 通道健康,次级通道让位
                switch result {
                case .event(let e) where e.kind == .cursor:
                    if !self.cursorHooksHealthy { NSLog("AgentDock: cursor hooks channel active") }
                    self.lastCursorHookAt = Date()
                case .event(let e) where e.kind == .claudeCode:
                    if !self.claudeHooksHealthy { NSLog("AgentDock: claude hooks channel active") }
                    self.lastClaudeHookAt = Date()
                default:
                    break
                }
                self.store.apply(result)
            }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            NSLog("AgentDock: socket server failed to start: \(error)")
        }
    }

    private func startCodexTailer() {
        let root = Self.home + "/.codex/sessions"
        guard FileManager.default.fileExists(atPath: root) else { return }
        let tailer = CodexSessionTailer(root: root) { _, sessionId, line in
            let result = EventIngestor.parseCodexRolloutLine(sessionId: sessionId, cwd: nil, line: line)
            Task { @MainActor [weak self] in self?.store.apply(result) }
        }
        tailer.start()
        codexTailer = tailer
    }

    /// Cursor 的 hooks 在部分版本上不可用(MainThreadShellExec not initialized),
    /// transcript 是唯一稳定的实时信号:秒级 tail,与 hooks 事件走同一状态机。
    private func startCursorTailer() {
        let root = Self.home + "/.cursor/projects"
        guard FileManager.default.fileExists(atPath: root) else { return }
        let tailer = CodexSessionTailer(
            root: root,
            // subagents/ 下是子 agent transcript,秒级通道也必须排除,
            // 否则会抢在 SQLite 子 agent 名单刷新前漏成重复会话
            pathFilter: { $0.contains("/agent-transcripts/") && !$0.contains("/subagents/") }
        ) { path, sessionId, line in
            // projects/<slug>/agent-transcripts/... → 从 slug 还原项目路径
            let cwd: String? = path.components(separatedBy: "/")
                .drop(while: { $0 != "projects" }).dropFirst().first
                .flatMap { SessionBackfillScanner.resolvePathSlug($0) }
            let result = EventIngestor.parseCursorTranscriptLine(
                sessionId: sessionId, cwd: cwd, line: line)
            Task { @MainActor [weak self] in
                guard let self, !self.cursorHooksHealthy else { return }
                self.store.apply(result)
            }
        }
        tailer.start()
        cursorTailer = tailer
    }

    /// 解析权限审批请求行:{"source":"claude-code","type":"permission","payload":{...}}
    nonisolated private static func parseApprovalRequest(
        _ line: Data, respond: @escaping @Sendable (String) -> Void
    ) -> SessionStore.PendingApproval? {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              obj["type"] as? String == "permission",
              let payload = obj["payload"] as? [String: Any],
              let sessionId = payload["session_id"] as? String
        else { return nil }
        let toolName = payload["tool_name"] as? String
        var detail: String?
        if let input = payload["tool_input"] as? [String: Any] {
            detail = (input["command"] as? String)
                ?? (input["file_path"] as? String).map { ($0 as NSString).lastPathComponent }
                ?? (input["url"] as? String)
        }
        return SessionStore.PendingApproval(sessionId: sessionId, toolName: toolName, detail: detail) { allow in
            respond(allow ? "allow" : "deny")
        }
    }

    /// 把 bundle 里的 agentdock-emit 复制到固定路径(hooks 配置引用它)
    private func installEmitScript() {
        guard let src = CoreResources.emitScriptPath else { return }
        let fm = FileManager.default
        try? fm.createDirectory(atPath: (Self.emitInstallPath as NSString).deletingLastPathComponent,
                                withIntermediateDirectories: true)
        try? fm.removeItem(atPath: Self.emitInstallPath)
        try? fm.copyItem(atPath: src, toPath: Self.emitInstallPath)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.emitInstallPath)
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.robot()
        item.button?.imagePosition = .imageLeft
        // 左键:展开/收起面板(两种挂靠模式通用);右键:退出菜单
        item.button?.target = self
        item.button?.action = #selector(statusItemPrimaryAction(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    /// 会话状态变化时刷新菜单栏图标颜色 / 数量 / 眨眼
    private func observeStatusItem() {
        withObservationTracking {
            _ = store.sessions.map { "\($0.id):\($0.state)" }
            _ = AppSettings.shared.panelPlacement
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshStatusItem()
                self?.observeStatusItem()
            }
        }
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        let menuBar = AppSettings.shared.panelPlacement == .menuBar
        let summary = statusSummary

        if menuBar {
            button.image = MenuBarIcon.robot(tint: summary.tint, eyesOpen: statusEyesOpen || !summary.blink)
            if summary.count > 0 {
                button.title = " \(summary.count)"
                button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
                // 标题色跟状态走,菜单栏深浅色下都够看
                button.contentTintColor = summary.titleColor
            } else {
                button.title = ""
                button.contentTintColor = nil
            }
            button.toolTip = summary.tooltip
            syncBlinkTimer(enabled: summary.blink)
        } else {
            // 刘海模式:经典模板图标,不占宽度、不眨眼
            button.image = MenuBarIcon.robot()
            button.title = ""
            button.contentTintColor = nil
            button.toolTip = nil
            syncBlinkTimer(enabled: false)
            statusEyesOpen = true
        }
        notchWindow?.statusButton = button
    }

    private struct StatusSummary {
        var tint: MenuBarIcon.Tint
        var count: Int
        var blink: Bool
        var tooltip: String
        var titleColor: NSColor?
    }

    /// 优先级:需要审批 > 运行中 > 其余(等待输入/仅有会话/无会话)一律模板色、无数字
    private var statusSummary: StatusSummary {
        let sessions = store.sessions
        let needsApproval = sessions.filter { $0.state == .waitingApproval }
        let running = sessions.filter { $0.state == .thinking || $0.state == .runningTool }
        let t = AppSettings.shared.t

        if !needsApproval.isEmpty {
            return StatusSummary(
                tint: .yellow,
                count: needsApproval.count,
                blink: true,
                tooltip: t("\(needsApproval.count) need approval",
                           "\(needsApproval.count) 个需要审批"),
                titleColor: NSColor(red: 0.82, green: 0.72, blue: 0.38, alpha: 1))
        }
        if !running.isEmpty {
            return StatusSummary(
                tint: .phosphor,
                count: running.count,
                blink: true,
                tooltip: t("\(running.count) running",
                           "\(running.count) 个运行中"),
                titleColor: NSColor(red: 0.45, green: 0.68, blue: 0.52, alpha: 1))
        }
        return StatusSummary(
            tint: .template,
            count: 0,
            blink: false,
            tooltip: t("AgentDock", "AgentDock"),
            titleColor: nil)
    }

    private func syncBlinkTimer(enabled: Bool) {
        if enabled {
            if statusBlinkTimer == nil {
                statusEyesOpen = true
                statusBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.statusEyesOpen.toggle()
                        self.refreshStatusItem()
                    }
                }
            }
        } else if let timer = statusBlinkTimer {
            timer.invalidate()
            statusBlinkTimer = nil
            statusEyesOpen = true
        }
    }

    @objc private func statusItemPrimaryAction(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            notchWindow?.togglePinned()
            return
        }
        switch event.type {
        case .rightMouseUp:
            showStatusItemMenu(from: sender)
        default:
            // 左键:两种模式都切换面板(刘海模式等同 ⌘G 固定展开)
            notchWindow?.togglePinned()
        }
    }

    private func showStatusItemMenu(from button: NSStatusBarButton) {
        let t = AppSettings.shared.t
        let menu = NSMenu()
        let quit = NSMenuItem(title: t("Quit AgentDock", "退出 AgentDock"),
                              action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        // popUp 相对按钮,右键菜单不抢左键
        let point = NSPoint(x: 0, y: button.bounds.height + 2)
        menu.popUp(positioning: nil, at: point, in: button)
    }

    // MARK: - 设置(面板内 tab)

    @objc func openSettings() {
        notchWindow?.hoverState.pinnedOpen = true
        notchWindow?.hoverState.activeTab = .settings
        notchWindow?.refreshVisibility()
    }

    @objc func quitApp() {
        AppQuit.quit()
    }
}
