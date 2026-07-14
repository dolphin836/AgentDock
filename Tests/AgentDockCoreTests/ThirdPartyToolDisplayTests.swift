import Testing
@testable import AgentDockCore

@Suite struct ThirdPartyToolDisplayTests {
    @Test func claudeDunderName() {
        #expect(ThirdPartyToolDisplay.label(
            tool: "mcp__plugin-notion-workspace-notion__search",
            detail: nil) == "notion/search")
    }

    @Test func cursorCallMcpWithDetail() {
        #expect(ThirdPartyToolDisplay.label(
            tool: "CallMcpTool",
            detail: "plugin-telegram-telegram/send_message") == "telegram/send_message")
    }

    @Test func wrapperWithoutDetailIsNil() {
        #expect(ThirdPartyToolDisplay.label(tool: "CallMcpTool", detail: nil) == nil)
        #expect(ThirdPartyToolDisplay.label(tool: "CallMcpTool", detail: "CallMcpTool") == nil)
    }

    @Test func builtinToolsAreNil() {
        #expect(ThirdPartyToolDisplay.label(tool: "Shell", detail: "ls") == nil)
        #expect(ThirdPartyToolDisplay.label(tool: "Read", detail: "foo.swift") == nil)
    }

    @Test func detailFromInput() {
        let input: [String: Any] = [
            "server": "plugin-notion-workspace-notion",
            "toolName": "search"
        ]
        #expect(ThirdPartyToolDisplay.detailFromInput(input, tool: "CallMcpTool")
                == "plugin-notion-workspace-notion/search")
    }

    @Test func shortenServer() {
        #expect(ThirdPartyToolDisplay.shortenServer("plugin-notion-workspace-notion") == "notion")
        #expect(ThirdPartyToolDisplay.shortenServer("plugin-telegram-telegram") == "telegram")
        #expect(ThirdPartyToolDisplay.shortenServer("plugin-claude-mem-mcp-search") == "search")
    }
}
