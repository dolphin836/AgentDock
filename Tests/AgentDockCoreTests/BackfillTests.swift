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

        let sessions = SessionBackfillScanner.scanClaude(projectsRoot: root)
        #expect(sessions.count == 1)
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
