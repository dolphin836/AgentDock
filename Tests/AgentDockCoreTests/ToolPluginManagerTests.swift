import Testing
@testable import AgentDockCore

@Suite struct ToolPluginManagerTests {
    @Test func actionsByAgentAndKind() {
        let claudePlug = ToolInventoryItem(
            id: "1", kind: .plugin, agent: .claudeCode,
            name: "telegram@claude-plugins-official")
        #expect(ToolPluginManager.actions(for: claudePlug)
                == [.checkUpdate, .update, .uninstall])

        let codexPlug = ToolInventoryItem(
            id: "2", kind: .plugin, agent: .codex,
            name: "browser@openai-bundled")
        #expect(ToolPluginManager.actions(for: codexPlug)
                == [.checkUpdate, .update, .uninstall])

        let cursorPlug = ToolInventoryItem(
            id: "3", kind: .plugin, agent: .cursor, name: "notion-workspace")
        #expect(ToolPluginManager.actions(for: cursorPlug) == [.openInHost])

        let skill = ToolInventoryItem(
            id: "4", kind: .skill, agent: .claudeCode, name: "demo",
            path: "/tmp/.claude/skills/demo")
        #expect(ToolPluginManager.actions(for: skill) == [.uninstall])

        let mcp = ToolInventoryItem(
            id: "5", kind: .mcp, agent: .claudeCode, name: "memory")
        #expect(ToolPluginManager.actions(for: mcp).isEmpty)
    }
}
