import Testing
import Foundation
import SQLite3
@testable import AgentDockCore

@Suite struct CodexStateReaderTests {
    @Test func readsRecentUnarchivedThreads() throws {
        let dir = NSTemporaryDirectory() + "agentdock-codex-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let dbPath = dir + "/state_5.sqlite"
        let rolloutPath = dir + "/rollout-t-live.jsonl"
        try #"{"timestamp":"2026-07-04T02:06:31.000Z","type":"event_msg","payload":{"type":"task_complete"}}"#
            .write(toFile: rolloutPath, atomically: true, encoding: .utf8)

        var db: OpaquePointer?
        #expect(sqlite3_open(dbPath, &db) == SQLITE_OK)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let ddl = """
        CREATE TABLE threads (id TEXT PRIMARY KEY, cwd TEXT, model TEXT, rollout_path TEXT,
                              archived INTEGER, recency_at_ms INTEGER);
        INSERT INTO threads VALUES ('t-live', '/Users/eric/Work/proj-x', 'gpt-5.5', '\(rolloutPath)', 0, \(nowMs - 60_000));
        INSERT INTO threads VALUES ('t-old', '/Users/eric/Work/old', 'gpt-5.5', '', 0, \(nowMs - 3 * 3600 * 1000));
        INSERT INTO threads VALUES ('t-archived', '/Users/eric/Work/arch', 'gpt-5.5', '', 1, \(nowMs));
        """
        #expect(sqlite3_exec(db, ddl, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        #expect(CodexStateReader.findDatabase(codexRoot: dir) == dbPath)
        let sessions = CodexStateReader.recentThreads(dbPath: dbPath)
        #expect(sessions.map(\.id) == ["t-live"])
        #expect(sessions[0].kind == .codex)
        #expect(sessions[0].projectName == "proj-x")
        #expect(sessions[0].metrics?.model == "gpt-5.5")
        #expect(sessions[0].state == .done)
    }
}
