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
        guard case .metrics(let sid, let m, let limits) = EventIngestor.parseLine(line) else {
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
        guard case .metrics(_, _, let limits) = EventIngestor.parseLine(line) else {
            Issue.record("expected .metrics"); return
        }
        #expect(limits == nil)
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
