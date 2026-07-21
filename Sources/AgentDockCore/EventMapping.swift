import Foundation

/// 各 Agent 原生事件名 → 统一状态。未知事件保持当前状态。
public func mapEventToState(_ event: AgentEvent, current: SessionState) -> SessionState {
    switch event.kind {
    case .claudeCode:
        switch event.name {
        case "SessionStart": return .idle
        case "UserPromptSubmit": return .thinking
        case "PreToolUse":
            if let tool = event.tool, isUserFacingTool(tool) { return .waitingInput }
            return .runningTool
        case "PostToolUse", "PostToolUseFailure", "SubagentStop", "PostCompact": return .thinking
        case "SubagentStart": return .runningTool
        case "PreCompact": return .thinking
        // MCP 服务器向用户请求输入
        case "Elicitation": return .waitingInput
        case "ElicitationResult": return .thinking
        case "Notification":
            // Claude Code 的 Notification 既用于权限审批,也用于「等你输入」提示,两者要区分展示
            if let detail = event.detail?.lowercased(), detail.contains("waiting for your input") {
                return .waitingInput
            }
            return .waitingApproval
        case "Stop", "SessionEnd": return .done
        default: return current
        }
    case .codex:
        switch event.name {
        case "agent-turn-complete", "turn_completed", "task_complete", "turn_aborted":
            return .done
        case "task_started", "user_message", "agent_message", "agent_reasoning",
             "reasoning", "message", "context_compacted":
            return .thinking
        // 新版 rollout:工具调用是 response_item/function_call 系列
        case "function_call", "custom_tool_call", "web_search_call", "tool_search_call",
             "exec_command_begin", "mcp_tool_call_begin", "patch_apply_begin":
            return .runningTool
        case "function_call_output", "custom_tool_call_output", "tool_search_output",
             "web_search_end", "exec_command_end", "mcp_tool_call_end", "patch_apply_end":
            return .thinking
        case "exec_approval_request", "apply_patch_approval_request", "elicitation_request":
            return .waitingApproval
        default: return current
        }
    case .cursor:
        switch event.name {
        case "sessionStart": return .idle
        case "beforeSubmitPrompt": return .thinking
        case "preToolUse", "beforeShellExecution", "beforeMCPExecution":
            // 提问/请求切换模式:agent 停下来等用户拍板,归入「等你处理」
            if let tool = event.tool, isUserFacingTool(tool) { return .waitingInput }
            return .runningTool
        case "postToolUse", "postToolUseFailure", "afterShellExecution", "afterMCPExecution":
            return .thinking
        // 子 agent 聚合注入:父会话有 Task 派生的子任务在跑(非真实 preToolUse,
        // 单独命名以免被当作工具调用 begin 反复计数)
        case "subagentProgress": return .runningTool
        case "subagentComplete": return .thinking
        // bubble 探测注入的审批卡片信号(Auto-review 拦截等)
        case "approvalRequest": return .waitingApproval
        case "approvalResolved": return .thinking
        case "stop", "sessionEnd": return .done
        default: return current
        }
    }
}

/// 需要用户回答/决定的工具调用(Cursor 的 AskQuestion/SwitchMode、
/// Claude 的 AskUserQuestion/ExitPlanMode 计划审批)
public func isUserFacingTool(_ tool: String) -> Bool {
    tool == "AskQuestion" || tool == "SwitchMode"
        || tool == "AskUserQuestion" || tool == "ExitPlanMode"
}
