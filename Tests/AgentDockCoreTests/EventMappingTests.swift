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
        // 新版 rollout 的 response_item 系列
        #expect(mapEventToState(ev("function_call", .codex), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("function_call_output", .codex), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("turn_aborted", .codex), current: .runningTool) == .done)
        #expect(mapEventToState(ev("user_message", .codex), current: .done) == .thinking)
    }

    @Test func claudeExtendedHookMapping() {
        #expect(mapEventToState(ev("SubagentStart"), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("SubagentStop"), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("Elicitation"), current: .runningTool) == .waitingInput)
        #expect(mapEventToState(ev("ElicitationResult"), current: .waitingInput) == .thinking)
    }

    @Test func userFacingToolsMapToWaitingInput() {
        let ask = AgentEvent(sessionId: "s1", kind: .cursor, name: "preToolUse",
                             detail: "AskQuestion", tool: "AskQuestion")
        #expect(mapEventToState(ask, current: .runningTool) == .waitingInput)
        let switchMode = AgentEvent(sessionId: "s1", kind: .cursor, name: "preToolUse",
                                    detail: "SwitchMode", tool: "SwitchMode")
        #expect(mapEventToState(switchMode, current: .thinking) == .waitingInput)
        let claudeAsk = AgentEvent(sessionId: "s1", kind: .claudeCode, name: "PreToolUse",
                                   detail: "AskUserQuestion", tool: "AskUserQuestion")
        #expect(mapEventToState(claudeAsk, current: .thinking) == .waitingInput)
        // 普通工具仍是执行中
        let shell = AgentEvent(sessionId: "s1", kind: .cursor, name: "preToolUse",
                               detail: "Shell", tool: "Shell")
        #expect(mapEventToState(shell, current: .thinking) == .runningTool)
    }

    @Test func cursorMapping() {
        #expect(mapEventToState(ev("sessionStart", .cursor), current: .done) == .idle)
        #expect(mapEventToState(ev("beforeSubmitPrompt", .cursor), current: .idle) == .thinking)
        #expect(mapEventToState(ev("preToolUse", .cursor), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("postToolUse", .cursor), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("stop", .cursor), current: .runningTool) == .done)
        #expect(mapEventToState(ev("sessionEnd", .cursor), current: .thinking) == .done)
        #expect(mapEventToState(ev("unknownEvent", .cursor), current: .runningTool) == .runningTool)
    }

    @Test func cursorSubagentProgressMapsToRunningTool() {
        let progress = AgentEvent(sessionId: "P", kind: .cursor, name: "subagentProgress",
                                  detail: "2 个子任务", tool: "Task")
        #expect(mapEventToState(progress, current: .thinking) == .runningTool)
        #expect(mapEventToState(progress, current: .done) == .runningTool)
        // 原始 hook 必须先经 Aggregator；若调用方漏拦，mapping 不得提前切状态。
        #expect(mapEventToState(ev("subagentStart", .cursor), current: .thinking) == .thinking)
        #expect(mapEventToState(ev("subagentStop", .cursor), current: .runningTool) == .runningTool)
    }

    @Test func cursorShellAndMCPHookMapping() {
        #expect(mapEventToState(ev("beforeShellExecution", .cursor), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("afterShellExecution", .cursor), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("beforeMCPExecution", .cursor), current: .thinking) == .runningTool)
        #expect(mapEventToState(ev("afterMCPExecution", .cursor), current: .runningTool) == .thinking)
        #expect(mapEventToState(ev("postToolUseFailure", .cursor), current: .runningTool) == .thinking)
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
