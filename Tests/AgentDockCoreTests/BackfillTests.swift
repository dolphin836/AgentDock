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
}
