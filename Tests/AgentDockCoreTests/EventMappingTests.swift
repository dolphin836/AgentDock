import Testing
import Foundation
@testable import AgentDockCore

private func ev(_ name: String, _ kind: AgentKind = .claudeCode) -> AgentEvent {
    AgentEvent(sessionId: "s1", kind: kind, name: name)
}

@Suite struct EventMappingTests {
    @Test func claudeHookMapping() {
        #expect(mapEventToState(ev("SessionStart"), current: .done) == .idle)
        #expect(mapEventToState(ev("UserPromptSubmit"), current: .idle) == .thinking)
        #expect(mapEventToState(ev("PreToolUse"), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("PostToolUse"), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("Notification"), current: .runningTool) == .waitingApproval)
        #expect(mapEventToState(ev("Stop"), current: .thinking) == .done)
        #expect(mapEventToState(ev("SessionEnd"), current: .thinking) == .done)
    }

    @Test func codexMapping() {
        #expect(mapEventToState(ev("agent-turn-complete", .codex), current: .thinking) == .done)
        #expect(mapEventToState(ev("task_started", .codex), current: .idle) == .thinking)
        #expect(mapEventToState(ev("exec_command_begin", .codex), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("exec_command_end", .codex), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("exec_approval_request", .codex), current: .runningTool) == .waitingApproval)
    }

    @Test func idleNotificationIsNotApproval() {
        let idle = AgentEvent(sessionId: "s1", kind: .claudeCode,
                              name: "Notification", detail: "Claude is waiting for your input")
        #expect(mapEventToState(idle, current: .thinking) == .waitingInput)
        let perm = AgentEvent(sessionId: "s1", kind: .claudeCode,
                              name: "Notification", detail: "Claude needs your permission to use Bash")
        #expect(mapEventToState(perm, current: .thinking) == .waitingApproval)
    }

    @Test func unknownEventKeepsCurrent() {
        #expect(mapEventToState(ev("SomethingNew"), current: .runningTool) == .runningTool)
        #expect(mapEventToState(ev("mystery", .codex), current: .thinking) == .thinking)
    }
}
