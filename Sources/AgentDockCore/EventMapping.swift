import Foundation

/// 各 Agent 原生事件名 → 统一状态。未知事件保持当前状态。
public func mapEventToState(_ event: AgentEvent, current: SessionState) -> SessionState {
    switch event.kind {
    case .claudeCode:
        switch event.name {
        case "SessionStart": return .idle
        case "UserPromptSubmit": return .thinking
        case "PreToolUse": return .runningTool
        case "PostToolUse": return .thinking
        case "Notification": return .waitingApproval
        case "Stop", "SessionEnd": return .done
        default: return current
        }
    case .codex:
        switch event.name {
        case "agent-turn-complete", "turn_completed", "task_complete":
            return .done
        case "task_started", "agent_message", "agent_reasoning":
            return .thinking
        case "exec_command_begin", "mcp_tool_call_begin", "patch_apply_begin":
            return .runningTool
        case "exec_command_end", "mcp_tool_call_end", "patch_apply_end":
            return .thinking
        case "exec_approval_request", "apply_patch_approval_request":
            return .waitingApproval
        default: return current
        }
    }
}
