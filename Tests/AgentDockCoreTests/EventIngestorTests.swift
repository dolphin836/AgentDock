import Testing
import Foundation
@testable import AgentDockCore

private func data(_ s: String) -> Data { Data(s.utf8) }

@Suite struct EventIngestorTests {
    @Test func claudeHookLine() {
        let line = data(#"{"source":"claude-code","type":"hook","payload":{"session_id":"abc","hook_event_name":"PreToolUse","cwd":"/Users/eric/proj","tool_name":"Bash"}}"#)
        guard case .event(let e) = EventIngestor.parseLine(line) else {
            Issue.record("expected .event"); return
        }
        #expect(e.sessionId == "abc")
        #expect(e.kind == .claudeCode)
        #expect(e.name == "PreToolUse")
        #expect(e.cwd == "/Users/eric/proj")
        #expect(e.detail == "Bash")
    }

    @Test func claudeStatuslineLine() {
        let line = data(#"{"source":"claude-code","type":"statusline","payload":{"session_id":"abc","model":{"display_name":"Opus"},"cost":{"total_cost_usd":1.25},"context_window":{"used_percentage":42,"total_input_tokens":80000,"total_output_tokens":4000},"rate_limits":{"five_hour":{"used_percentage":23.5},"seven_day":{"used_percentage":41}}}}"#)
        guard case .metrics(let sid, .claudeCode, let m, let limits) = EventIngestor.parseLine(line) else {
            Issue.record("expected .metrics"); return
        }
        #expect(sid == "abc")
        #expect(m.model == "Opus")
        #expect(m.costUSD == 1.25)
        #expect(m.contextPct == 42)
        #expect(m.totalTokens == 84000)
        #expect(limits?.fiveHourPct == 23)
        #expect(limits?.sevenDayPct == 41)
    }

    @Test func statuslineWithoutRateLimits() {
        let line = data(#"{"source":"claude-code","type":"statusline","payload":{"session_id":"abc","model":{"display_name":"Opus"}}}"#)
        guard case .metrics(_, _, _, let limits) = EventIngestor.parseLine(line) else {
            Issue.record("expected .metrics"); return
        }
        #expect(limits == nil)
    }

    @Test func codexTokenCountLine() {
        let line = data("""
        {"timestamp":"2026-07-06T09:38:35.000Z","type":"event_msg","payload":{"type":"token_count",\
        "info":{"total_token_usage":{"total_tokens":95756},\
        "last_token_usage":{"total_tokens":24057},"model_context_window":258400},\
        "rate_limits":{"primary":{"used_percent":1.0,"window_minutes":300},\
        "secondary":{"used_percent":98.0,"window_minutes":10080}}}}
        """)
        guard case .metrics(let sid, .codex, let m, let limits) =
            EventIngestor.parseCodexRolloutLine(sessionId: "t1", cwd: nil, line: line) else {
            Issue.record("expected .metrics"); return
        }
        #expect(sid == "t1")
        #expect(m.totalTokens == 24057)      // 当前 context 占用,不是累计
        #expect(m.contextPct == 9)           // 24057/258400
        #expect(limits?.fiveHourPct == 1)    // primary = 5 小时窗口
        #expect(limits?.sevenDayPct == 98)   // secondary = 周窗口
    }

    @Test func codexNotifyLine() {
        let line = data(#"{"source":"codex","type":"notify","payload":{"type":"agent-turn-complete","turn-id":"t9","last-assistant-message":"done"}}"#)
        guard case .event(let e) = EventIngestor.parseLine(line) else {
            Issue.record("expected .event"); return
        }
        #expect(e.sessionId == "t9")
        #expect(e.kind == .codex)
        #expect(e.name == "agent-turn-complete")
    }

    @Test func cursorHookEvent() {
        let line = data("""
        {"source":"cursor","type":"hook","app":"/Applications/Cursor.app","payload":{
          "conversation_id":"conv-1","hook_event_name":"preToolUse","model":"fable-5",
          "tool_name":"Shell","tool_input":{"command":"swift test"},
          "workspace_roots":["/Users/eric/AgentDock"]}}
        """)
        guard case .event(let e) = EventIngestor.parseLine(line) else {
            Issue.record("expected .event"); return
        }
        #expect(e.sessionId == "conv-1")
        #expect(e.kind == .cursor)
        #expect(e.name == "preToolUse")
        #expect(e.cwd == "/Users/eric/AgentDock")
        #expect(e.detail == "swift test")
        #expect(e.model == "fable-5")
        #expect(e.appPath == "/Applications/Cursor.app")
    }

    @Test func cursorMcpHookKeepsServerToolDetail() {
        let line = data("""
        {"source":"cursor","type":"hook","payload":{
          "conversation_id":"conv-mcp","hook_event_name":"preToolUse",
          "tool_name":"CallMcpTool",
          "tool_input":{"server":"plugin-notion-workspace-notion","toolName":"search"},
          "workspace_roots":["/Users/eric/AgentDock"]}}
        """)
        guard case .event(let e) = EventIngestor.parseLine(line) else {
            Issue.record("expected .event"); return
        }
        #expect(e.tool == "CallMcpTool")
        #expect(e.detail == "plugin-notion-workspace-notion/search")
        #expect(ThirdPartyToolDisplay.label(tool: e.tool, detail: e.detail) == "notion/search")
    }

    @Test func cursorTranscriptLines() {
        func parse(_ s: String) -> IngestResult {
            EventIngestor.parseCursorTranscriptLine(sessionId: "c1", cwd: "/x/p", line: data(s))
        }
        guard case .event(let submit) = parse(#"{"role":"user","message":{"content":[{"type":"text","text":"go"}]}}"#) else {
            Issue.record("expected .event"); return
        }
        #expect(submit.name == "beforeSubmitPrompt")
        #expect(submit.kind == .cursor)
        #expect(submit.cwd == "/x/p")

        guard case .event(let tool) = parse(#"{"role":"assistant","message":{"content":[{"type":"text","text":"x"},{"type":"tool_use","name":"Shell"}]}}"#) else {
            Issue.record("expected .event"); return
        }
        #expect(tool.name == "preToolUse")
        #expect(tool.detail == "Shell")

        guard case .event(let text) = parse(#"{"role":"assistant","message":{"content":[{"type":"text","text":"done"}]}}"#) else {
            Issue.record("expected .event"); return
        }
        #expect(text.name == "postToolUse")

        guard case .event(let ended) = parse(#"{"type":"turn_ended","status":"success"}"#) else {
            Issue.record("expected .event"); return
        }
        #expect(ended.name == "stop")
    }

    @Test func codexRolloutLine() {
        let line = data(#"{"timestamp":"2026-07-02T10:00:00Z","type":"event_msg","payload":{"type":"exec_command_begin","command":"ls"}}"#)
        guard case .event(let e) = EventIngestor.parseCodexRolloutLine(sessionId: "r1", cwd: "/tmp/x", line: line) else {
            Issue.record("expected .event"); return
        }
        #expect(e.sessionId == "r1")
        #expect(e.name == "exec_command_begin")
        #expect(e.detail == "ls")
    }

    @Test func garbageIsIgnored() {
        #expect(EventIngestor.parseLine(data("not json")) == .ignored)
        #expect(EventIngestor.parseLine(data(#"{"source":"claude-code"}"#)) == .ignored)
        #expect(EventIngestor.parseLine(data(#"{"source":"claude-code","type":"hook","payload":{}}"#)) == .ignored)
        #expect(EventIngestor.parseCodexRolloutLine(sessionId: "x", cwd: nil, line: data("{}")) == .ignored)
    }
}
