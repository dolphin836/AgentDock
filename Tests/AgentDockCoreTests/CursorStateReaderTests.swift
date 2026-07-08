import Testing
import Foundation
import SQLite3
@testable import AgentDockCore

@Suite struct CursorStateReaderTests {
    @Test func readsMetricsAndFiltersSubagents() throws {
        let dir = NSTemporaryDirectory() + "agentdock-cursor-db-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let dbPath = dir + "/state.vscdb"

        var db: OpaquePointer?
        #expect(sqlite3_open(dbPath, &db) == SQLITE_OK)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        func composer(_ id: String, _ json: String) -> String {
            "INSERT INTO cursorDiskKV VALUES ('composerData:\(id)', '\(json)');"
        }
        let main = """
        {"modelConfig":{"modelName":"claude-fable-5"},"contextUsagePercent":23.7,\
        "contextTokensUsed":237172,"lastUpdatedAt":\(nowMs - 60_000),\
        "workspaceIdentifier":{"uri":{"fsPath":"/Users/eric/AgentDock"}},\
        "isDraft":false,"isBestOfNSubcomposer":false,\
        "subComposerIds":["sub-1"],"subagentComposerIds":["sub-2"]}
        """
        let old = """
        {"modelConfig":{"modelName":"gpt"},"lastUpdatedAt":\(nowMs - 3 * 3600 * 1000),\
        "workspaceIdentifier":{"uri":{"fsPath":"/x/old"}},"isDraft":false}
        """
        let draft = """
        {"lastUpdatedAt":\(nowMs),"workspaceIdentifier":{"uri":{"fsPath":"/x/d"}},"isDraft":true}
        """
        let ddl = "CREATE TABLE cursorDiskKV (key TEXT PRIMARY KEY, value BLOB);"
            + composer("conv-main", main) + composer("conv-old", old) + composer("conv-draft", draft)
        #expect(sqlite3_exec(db, ddl, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let snapshot = CursorStateReader.recentConversations(dbPath: dbPath)
        #expect(snapshot.sessions.count == 1)  // 过老的、草稿都不要
        let s = snapshot.sessions[0]
        #expect(s.id == "conv-main")
        #expect(s.kind == .cursor)
        #expect(s.cwd == "/Users/eric/AgentDock")
        #expect(s.metrics?.model == "claude-fable-5")
        #expect(s.metrics?.contextPct == 24)
        #expect(s.metrics?.totalTokens == 237172)
        #expect(s.state == .disconnected)  // 该来源不决定状态
        #expect(snapshot.subagentIds == ["sub-1", "sub-2"])
    }
}
