import Testing
import Foundation
@testable import AgentDockCore

@Suite struct ToolInventoryTests {
    @Test func scansClaudePluginsSkillsAndMcp() throws {
        let root = NSTemporaryDirectory() + "agentdock-inv-\(UUID().uuidString.prefix(8))"
        defer { try? FileManager.default.removeItem(atPath: root) }
        let fm = FileManager.default
        try fm.createDirectory(atPath: root + "/.claude/plugins", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: root + "/.claude/skills/demo-skill", withIntermediateDirectories: true)
        try "# Demo\n".write(toFile: root + "/.claude/skills/demo-skill/SKILL.md",
                             atomically: true, encoding: .utf8)
        let plugins = """
        {"version":2,"plugins":{"telegram@claude-plugins-official":[{"version":"0.0.6","installPath":"\(root)/.claude/plugins/cache/telegram"}]}}
        """
        try plugins.write(toFile: root + "/.claude/plugins/installed_plugins.json",
                          atomically: true, encoding: .utf8)
        try #"{"mcpServers":{"memory":{"command":"npx"}}}"#
            .write(toFile: root + "/.claude.json", atomically: true, encoding: .utf8)

        let items = ToolInventoryScanner.scan(home: root)
            .first { $0.agent == .claudeCode }?.items ?? []
        #expect(items.contains { $0.kind == .plugin && $0.displayName == "telegram" })
        #expect(items.contains { $0.kind == .skill && $0.name == "demo-skill" })
        #expect(items.contains { $0.kind == .mcp && $0.name == "memory" })
    }

    @Test func parsesCodexTomlPluginAndMcpNames() {
        let text = """
        [plugins."browser@openai-bundled"]
        enabled = true
        [plugins."hidden@x"]
        enabled = false
        [mcp_servers.node_repl]
        command = "node"
        [mcp_servers.computer-use]
        enabled = false
        """
        let plugins = ToolInventoryScanner.tomlTableNames(text, prefix: "plugins.")
        #expect(plugins.contains("browser@openai-bundled"))
        #expect(ToolInventoryScanner.tomlBool(text, table: "plugins.\"browser@openai-bundled\"", key: "enabled") == true)
        #expect(ToolInventoryScanner.tomlBool(text, table: "plugins.\"hidden@x\"", key: "enabled") == false)
        #expect(ToolInventoryScanner.tomlBool(text, table: "mcp_servers.computer-use", key: "enabled") == false)
    }

    @Test func matchesUsageToInventoryItem() {
        let item = ToolInventoryItem(
            id: "x", kind: .mcp, agent: .cursor, name: "plugin-notion-workspace-notion",
            displayName: "notion")
        let stats = [
            ToolUsageStat(toolKey: "notion/search", callCount: 3,
                          lastUsedAt: Date(timeIntervalSince1970: 100)),
            ToolUsageStat(toolKey: "Bash", callCount: 9, lastUsedAt: nil),
        ]
        let hit = ToolInventoryScanner.usage(for: item, stats: stats)
        #expect(hit?.callCount == 3)
    }
}

@Suite struct ToolCallHistoryTests {
    @Test func recordsAndAggregatesToolCalls() {
        let store = HistoryStore(path: NSTemporaryDirectory()
            + "agentdock-tools-\(UUID().uuidString.prefix(8)).sqlite")
        let base = Date(timeIntervalSince1970: 1_800_200_000)
        store.recordToolCallBegin(sessionId: "s1", kind: .cursor, toolKey: "notion/search",
                                  toolRaw: "CallMcpTool", at: base)
        store.recordToolCallEnd(sessionId: "s1", toolKey: "notion/search",
                                at: base.addingTimeInterval(4))
        store.recordToolCallBegin(sessionId: "s1", kind: .cursor, toolKey: "notion/search",
                                  toolRaw: "CallMcpTool", at: base.addingTimeInterval(10))
        store.recordToolCallEnd(sessionId: "s1", toolKey: "notion/search",
                                at: base.addingTimeInterval(16))
        store.recordToolCallBegin(sessionId: "s2", kind: .cursor, toolKey: "telegram/send_message",
                                  toolRaw: "CallMcpTool", at: base.addingTimeInterval(20))
        store.recordToolCallEnd(sessionId: "s2", toolKey: "telegram/send_message",
                                at: base.addingTimeInterval(25))
        store.flush()

        let rows = store.toolUsage(kind: .cursor)
        let notion = rows.first { $0.toolKey == "notion/search" }
        #expect(notion?.callCount == 2)
        #expect(notion?.totalDurationSeconds == 10) // 4 + 6
        let summary = store.toolUsageSummary(kind: .cursor)
        #expect(summary.count == 3)
        #expect(summary.totalDurationSeconds == 15)
        #expect(summary.lastUsedAt == base.addingTimeInterval(20))
    }
}
