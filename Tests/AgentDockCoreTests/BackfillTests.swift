import Testing
import Foundation
@testable import AgentDockCore

@Suite struct SessionBackfillScannerTests {
    @Test func scansRecentTranscriptsAndExtractsCwd() throws {
        let root = NSTemporaryDirectory() + "agentdock-scan-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: root + "/proj-a", withIntermediateDirectories: true)
        try #"{"type":"session_start","cwd":"/Users/eric/Work/proj-a","session_id":"s-recent"}"#
            .write(toFile: root + "/proj-a/s-recent.jsonl", atomically: true, encoding: .utf8)
        // 过老的文件应被忽略
        let oldPath = root + "/proj-a/s-old.jsonl"
        try "{}".write(toFile: oldPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-3 * 3600)], ofItemAtPath: oldPath)

        // 带 usage 的 assistant 行,应被提取为离线指标
        let usageLine = #"{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"input_tokens":100,"cache_read_input_tokens":50000,"cache_creation_input_tokens":900,"output_tokens":400}}}"#
        let h = FileHandle(forWritingAtPath: root + "/proj-a/s-recent.jsonl")!
        try h.seekToEnd(); try h.write(contentsOf: Data(("\n" + usageLine + "\n").utf8)); try h.close()

        // 隐藏目录(工具后台会话)应被过滤
        try FileManager.default.createDirectory(atPath: root + "/mem", withIntermediateDirectories: true)
        try #"{"cwd":"/Users/eric/.claude-mem/observer-sessions"}"#
            .write(toFile: root + "/mem/s-observer.jsonl", atomically: true, encoding: .utf8)

        let sessions = SessionBackfillScanner.scanClaude(projectsRoot: root)
        #expect(sessions.count == 1)
        #expect(sessions[0].metrics?.model == "claude-opus-4-8")
        #expect(sessions[0].metrics?.totalTokens == 51400)
        #expect(sessions[0].metrics?.contextPct == 25)  // 51000/200000
        #expect(sessions[0].id == "s-recent")
        #expect(sessions[0].cwd == "/Users/eric/Work/proj-a")
        #expect(sessions[0].projectName == "proj-a")
        #expect(sessions[0].state == .waitingInput)
    }

    @Test func codexBackfillUsesRolloutTerminalState() throws {
        let root = NSTemporaryDirectory() + "agentdock-codex-scan-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: root + "/2026/07/04", withIntermediateDirectories: true)
        let path = root + "/2026/07/04/rollout-2026-07-04T11-01-08-t-done.jsonl"
        let lines = [
            #"{"timestamp":"2026-07-04T02:01:08.000Z","type":"event_msg","payload":{"type":"task_started"}}"#,
            #"{"timestamp":"2026-07-04T02:06:31.000Z","type":"event_msg","payload":{"type":"task_complete"}}"#,
        ].joined(separator: "\n")
        try lines.write(toFile: path, atomically: true, encoding: .utf8)

        let sessions = SessionBackfillScanner.scanCodex(root: root)
        #expect(sessions.count == 1)
        // id 必须是线程 uuid(去掉 rollout-<时间戳>- 前缀),与 SQLite/notify 对齐
        #expect(sessions[0].id == "t-done")
        #expect(sessions[0].state == .done)
        #expect(SessionBackfillScanner.inferCodexState(path: path) == .done)
    }

    @Test func cursorScanResolvesSlugAndInfersState() throws {
        let root = NSTemporaryDirectory() + "agentdock-cursor-\(UUID().uuidString.prefix(8))"
        // 造一个真实存在的项目目录,让 slug 猜解命中
        let projectDir = root + "/proj/my-app"
        try FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)
        let slug = String(projectDir.dropFirst()).replacingOccurrences(of: "/", with: "-")

        let cursorProjects = root + "/cursor-projects"
        let transcripts = cursorProjects + "/\(slug)/agent-transcripts/conv-1"
        try FileManager.default.createDirectory(atPath: transcripts, withIntermediateDirectories: true)
        let lines = [
            #"{"role":"user","message":{"content":[{"type":"text","text":"hi"}]}}"#,
            #"{"role":"assistant","message":{"content":[{"type":"text","text":"done"}]}}"#,
            #"{"type":"turn_ended","status":"success"}"#,
        ].joined(separator: "\n")
        try lines.write(toFile: transcripts + "/conv-1.jsonl", atomically: true, encoding: .utf8)

        // subagents/ 下的子 agent transcript 不是用户会话,必须排除
        try FileManager.default.createDirectory(atPath: transcripts + "/subagents",
                                                withIntermediateDirectories: true)
        try #"{"role":"user","message":{"content":[{"type":"text","text":"sub"}]}}"#
            .write(toFile: transcripts + "/subagents/sub-1.jsonl", atomically: true, encoding: .utf8)

        // 测试项目在系统临时目录下,排除临时路径的默认过滤要关掉
        let sessions = SessionBackfillScanner.scanCursor(projectsRoot: cursorProjects,
                                                         excludedCwdPrefixes: [])
        #expect(sessions.count == 1)
        #expect(sessions[0].id == "conv-1")
        #expect(sessions[0].kind == .cursor)
        #expect(sessions[0].cwd == projectDir)
        #expect(sessions[0].projectName == "my-app")
        #expect(sessions[0].state == .done)  // turn_ended → 回合结束
    }

    @Test func cursorStateInference() throws {
        let dir = NSTemporaryDirectory() + "agentdock-cursor-state-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let running = dir + "/running.jsonl"
        try #"{"role":"assistant","message":{"content":[{"type":"text","text":"x"},{"type":"tool_use","name":"Shell"}]}}"#
            .write(toFile: running, atomically: true, encoding: .utf8)
        #expect(SessionBackfillScanner.inferCursorState(path: running) == .runningTool)

        let thinking = dir + "/thinking.jsonl"
        try #"{"role":"user","message":{"content":[{"type":"text","text":"go"}]}}"#
            .write(toFile: thinking, atomically: true, encoding: .utf8)
        #expect(SessionBackfillScanner.inferCursorState(path: thinking) == .thinking)
    }

    @Test func pathSlugResolution() {
        // 模拟文件系统:/Users/eric/Work 下有 platform-debit-card(目录名带连字符)
        let dirs: Set<String> = ["/Users", "/Users/eric", "/Users/eric/Work",
                                 "/Users/eric/Work/platform-debit-card"]
        let exists: (String) -> Bool = { dirs.contains($0) }
        #expect(SessionBackfillScanner.resolvePathSlug(
            "Users-eric-Work-platform-debit-card", directoryExists: exists)
            == "/Users/eric/Work/platform-debit-card")
        #expect(SessionBackfillScanner.resolvePathSlug("Users-eric-Work", directoryExists: exists)
            == "/Users/eric/Work")
        #expect(SessionBackfillScanner.resolvePathSlug("no-such-root", directoryExists: exists) == nil)
        #expect(SessionBackfillScanner.resolvePathSlug("empty-window", directoryExists: exists) == nil)
    }

    @Test func codexThreadIdExtraction() {
        #expect(SessionBackfillScanner.codexThreadId(
            fromRolloutName: "rollout-2026-07-04T10-21-24-019f2ab7-513b-7083-95e4-58f8b095e141")
            == "019f2ab7-513b-7083-95e4-58f8b095e141")
        // 不匹配约定格式时原样返回
        #expect(SessionBackfillScanner.codexThreadId(fromRolloutName: "rollout-weird") == "rollout-weird")
        #expect(SessionBackfillScanner.codexThreadId(fromRolloutName: "abc") == "abc")
    }
}

@MainActor
@Suite struct SessionStoreBackfillTests {
    @Test func backfillInsertsButNeverOverridesLiveState() {
        let store = SessionStore()
        let now = Date()
        // 实时事件建立的会话
        store.apply(.event(AgentEvent(sessionId: "live", kind: .claudeCode,
                                      cwd: "/x/live", name: "PreToolUse", timestamp: now)))
        // 回填:live 的磁盘 mtime 较旧 → 不动;fresh 是新会话 → 插入
        store.backfill([
            AgentSession(id: "live", kind: .claudeCode, projectName: "live", cwd: "/x/live",
                         state: .waitingInput, lastActivity: now.addingTimeInterval(-300)),
            AgentSession(id: "fresh", kind: .claudeCode, projectName: "fresh", cwd: "/x/fresh",
                         state: .waitingInput, lastActivity: now.addingTimeInterval(-60)),
        ])
        #expect(store.sessions.count == 2)
        #expect(store.sessions.first(where: { $0.id == "live" })?.state == .runningTool)
        #expect(store.sessions.first(where: { $0.id == "fresh" })?.state == .waitingInput)
    }

    @Test func backfillAdoptsTerminalStateForExistingSession() {
        let store = SessionStore()
        let now = Date()
        store.backfill([
            AgentSession(id: "stale", kind: .codex, projectName: "stale", cwd: "/x/stale",
                         state: .waitingInput, lastActivity: now),
        ])
        store.backfill([
            AgentSession(id: "stale", kind: .codex, projectName: "stale", cwd: "/x/stale",
                         state: .done, lastActivity: now),
        ])

        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].state == .done)
    }

    @Test func backfillNeverRevivesDisconnectedSessionWithoutNewActivity() {
        let store = SessionStore()
        let stale = Date().addingTimeInterval(-30 * 60)  // 超过 disconnectAfter(10 分钟)
        // rollout 尾部停在 thinking 的僵尸线程:插入时即判断为 disconnected
        store.backfill([
            AgentSession(id: "zombie", kind: .codex, projectName: "z", cwd: "/x/z",
                         state: .thinking, lastActivity: stale),
        ])
        #expect(store.sessions[0].state == .disconnected)

        // 磁盘无新写入(mtime 不变),每分钟的回填不得把它复活成 thinking
        store.prune()
        store.backfill([
            AgentSession(id: "zombie", kind: .codex, projectName: "z", cwd: "/x/z",
                         state: .thinking, lastActivity: stale),
        ])
        #expect(store.sessions[0].state == .disconnected)
    }

    @Test func deadCodexCliSessionConvergesToDone() {
        let store = SessionStore()
        // /x/dead 没有活着的 codex 进程;/x/alive 有
        store.codexLivenessCheck = { $0.cwd == "/x/alive" }
        let now = Date()
        store.backfill([
            AgentSession(id: "dead", kind: .codex, projectName: "dead", cwd: "/x/dead",
                         state: .waitingInput, lastActivity: now),
            AgentSession(id: "alive", kind: .codex, projectName: "alive", cwd: "/x/alive",
                         state: .waitingInput, lastActivity: now),
        ])
        #expect(store.sessions.first(where: { $0.id == "dead" })?.state == .done)
        #expect(store.sessions.first(where: { $0.id == "alive" })?.state == .waitingInput)
    }

    @Test func backfillFillsMissingMetricFieldsWithoutOverwriting() {
        let store = SessionStore()
        let now = Date()
        // 实时 hook 只带了模型名
        store.apply(.event(AgentEvent(sessionId: "c1", kind: .cursor, cwd: "/x/p",
                                      name: "preToolUse", model: "fable-5", timestamp: now)))
        // 磁盘状态库较旧,但带 ctx%/tokens:只补缺失字段,不覆盖已有模型名
        var m = Metrics(model: "stale-model", contextPct: 24, costUSD: nil, totalTokens: 237_000)
        m.model = "stale-model"
        store.backfill([
            AgentSession(id: "c1", kind: .cursor, projectName: "p", cwd: "/x/p",
                         state: .disconnected, metrics: m,
                         lastActivity: now.addingTimeInterval(-30)),
        ])
        let session = store.sessions.first(where: { $0.id == "c1" })
        #expect(session?.metrics?.model == "fable-5")     // 实时值保留
        #expect(session?.metrics?.contextPct == 24)       // 缺失字段补上
        #expect(session?.metrics?.totalTokens == 237_000)
        #expect(session?.state == .runningTool)           // disconnected 不覆盖实时态
    }

    @Test func backfillFillsMissingAppPath() {
        let store = SessionStore()
        let now = Date()
        store.backfill([
            AgentSession(id: "s1", kind: .codex, projectName: "p", cwd: "/x/p",
                         state: .waitingInput, lastActivity: now),
        ])
        store.backfill([
            AgentSession(id: "s1", kind: .codex, projectName: "p", cwd: "/x/p",
                         state: .waitingInput, appPath: "/Applications/Codex.app", lastActivity: now),
        ])
        #expect(store.sessions[0].appPath == "/Applications/Codex.app")
    }
}
