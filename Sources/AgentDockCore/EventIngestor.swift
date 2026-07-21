import Foundation

public enum IngestResult: Sendable, Equatable {
    case event(AgentEvent)
    case metrics(sessionId: String, kind: AgentKind, Metrics, RateLimits?)
    case ignored
}

/// 解析发射脚本经 socket 送来的 NDJSON 行:
/// {"source":"claude-code"|"codex","type":"hook"|"statusline"|"notify","payload":{...}}
/// 任何格式问题一律返回 .ignored,绝不抛错。
public enum EventIngestor {

    public static func parseLine(_ line: Data) -> IngestResult {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let source = obj["source"] as? String,
              let type = obj["type"] as? String,
              let payload = obj["payload"] as? [String: Any]
        else { return .ignored }

        let appPath = (obj["app"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        switch (source, type) {
        case ("claude-code", "hook"):
            return parseClaudeHook(payload, appPath: appPath)
        case ("claude-code", "statusline"):
            return parseClaudeStatusline(payload)
        case ("codex", "notify"):
            return parseCodexNotify(payload, appPath: appPath)
        case ("cursor", "hook"):
            return parseCursorHook(payload, appPath: appPath)
        default:
            return .ignored
        }
    }

    /// Cursor hook stdin:{"hook_event_name":"preToolUse","conversation_id":"...",
    /// "workspace_roots":["/path"],"model":"...","tool_name":...,"tool_input":{...}}
    private static func parseCursorHook(_ p: [String: Any], appPath: String?) -> IngestResult {
        guard let sessionId = (p["conversation_id"] as? String) ?? (p["session_id"] as? String),
              let name = p["hook_event_name"] as? String
        else { return .ignored }
        let tool = p["tool_name"] as? String
        let input = p["tool_input"] as? [String: Any]
        let detail = toolDetail(tool: tool, input: input, fallback: tool)
        let cwd = (p["workspace_roots"] as? [String])?.first
        let correlationId = (p["tool_use_id"] as? String)
            ?? (p["tool_call_id"] as? String)
        let transcriptIdentity = (p["agent_transcript_path"] as? String)
            .map(SessionBackfillScanner.cursorTranscriptIdentity(path:))
        let parentSessionId = (p["parent_conversation_id"] as? String)
            ?? transcriptIdentity.flatMap(\.parentId)
        // 官方 hook 在父会话上下文触发:subagent_id 实为父 Task 的 tool_call_id,而
        // agent_transcript_path 的 stem 是子会话 uuid——同一逻辑子任务的两个别名,都登记。
        let explicitSubagentId = p["subagent_id"] as? String
        let transcriptChildId = transcriptIdentity.flatMap { $0.isSubagent ? $0.sessionId : nil }
        let subagentId = explicitSubagentId ?? transcriptChildId
        let subagentAliases = Array(Set([explicitSubagentId, transcriptChildId].compactMap { $0 }))
        return .event(AgentEvent(
            sessionId: sessionId, kind: .cursor,
            cwd: cwd, name: name, detail: detail, tool: tool, appPath: appPath,
            model: p["model"] as? String, correlationId: correlationId,
            parentSessionId: parentSessionId, subagentId: subagentId,
            subagentAliases: subagentAliases))
    }

    private static func parseClaudeHook(_ p: [String: Any], appPath: String?) -> IngestResult {
        guard let sessionId = p["session_id"] as? String,
              let name = p["hook_event_name"] as? String
        else { return .ignored }
        let tool = p["tool_name"] as? String
        let input = p["tool_input"] as? [String: Any]
        let detail = toolDetail(tool: tool, input: input,
                                fallback: tool ?? (p["message"] as? String))
        return .event(AgentEvent(
            sessionId: sessionId, kind: .claudeCode,
            cwd: p["cwd"] as? String, name: name, detail: detail, tool: tool, appPath: appPath))
    }

    /// detail 优先级:MCP server/tool → 文件名 → shell 命令 → fallback
    private static func toolDetail(tool: String?, input: [String: Any]?,
                                   fallback: String?) -> String? {
        if let mcp = ThirdPartyToolDisplay.detailFromInput(input, tool: tool) {
            return mcp
        }
        if let input {
            if let filePath = input["file_path"] as? String, !filePath.isEmpty {
                return (filePath as NSString).lastPathComponent
            }
            if let command = input["command"] as? String, !command.isEmpty {
                return command
            }
        }
        return fallback
    }

    private static func parseClaudeStatusline(_ p: [String: Any]) -> IngestResult {
        guard let sessionId = p["session_id"] as? String else { return .ignored }
        var m = Metrics()
        if let model = p["model"] as? [String: Any] {
            m.model = model["display_name"] as? String
        }
        if let cost = p["cost"] as? [String: Any] {
            m.costUSD = cost["total_cost_usd"] as? Double
        }
        if let ctx = p["context_window"] as? [String: Any] {
            if let pct = intValue(ctx["used_percentage"]) { m.contextPct = pct }
            // 当前 context 内的 input+output token 数(/compact 后会重置)
            let input = ctx["total_input_tokens"] as? Int ?? 0
            let output = ctx["total_output_tokens"] as? Int ?? 0
            if input + output > 0 { m.totalTokens = input + output }
        }
        // 账号级限额(Pro/Max 订阅时 statusline 会带)
        var limits: RateLimits?
        if let r = p["rate_limits"] as? [String: Any] {
            var l = RateLimits()
            if let w = r["five_hour"] as? [String: Any] { l.fiveHourPct = intValue(w["used_percentage"]) }
            if let w = r["seven_day"] as? [String: Any] { l.sevenDayPct = intValue(w["used_percentage"]) }
            if l.fiveHourPct != nil || l.sevenDayPct != nil { limits = l }
        }
        return .metrics(sessionId: sessionId, kind: .claudeCode, m, limits)
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        return nil
    }

    private static func parseCodexNotify(_ p: [String: Any], appPath: String?) -> IngestResult {
        guard let name = p["type"] as? String else { return .ignored }
        let sessionId = (p["thread-id"] as? String) ?? (p["turn-id"] as? String) ?? "codex"
        return .event(AgentEvent(
            sessionId: sessionId, kind: .codex,
            cwd: p["cwd"] as? String, name: name,
            detail: p["last-assistant-message"] as? String, appPath: appPath))
    }

    /// 解析 Cursor agent transcript 的一行,映射成与 hooks 同名的事件
    /// (tail 通道与 hooks 通道共享一套状态机)。
    public static func parseCursorTranscriptLine(sessionId: String, cwd: String?, line: Data) -> IngestResult {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
        else { return .ignored }
        if obj["type"] as? String == "turn_ended" {
            return .event(AgentEvent(sessionId: sessionId, kind: .cursor, cwd: cwd, name: "stop"))
        }
        guard let role = obj["role"] as? String else { return .ignored }
        if role == "user" {
            return .event(AgentEvent(
                sessionId: sessionId, kind: .cursor, cwd: cwd, name: "beforeSubmitPrompt"))
        }
        guard role == "assistant" else { return .ignored }
        let content = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
        let toolUse = content.last { $0["type"] as? String == "tool_use" }
        if let toolUse {
            let tool = toolUse["name"] as? String
            let correlationId = (toolUse["id"] as? String)
                ?? (toolUse["tool_use_id"] as? String)
                ?? (toolUse["tool_call_id"] as? String)
            return .event(AgentEvent(
                sessionId: sessionId, kind: .cursor, cwd: cwd,
                name: "preToolUse", detail: tool, tool: tool,
                correlationId: correlationId))
        }
        return .event(AgentEvent(sessionId: sessionId, kind: .cursor, cwd: cwd, name: "postToolUse"))
    }

    /// 解析 Codex rollout JSONL 的一行(由 CodexSessionTailer 提供 sessionId/cwd 上下文)。
    /// 新版 rollout 的工具调用是 response_item/function_call(name=exec_command/apply_patch...),
    /// 旧版是 event_msg/exec_command_begin,两代格式都支持。
    public static func parseCodexRolloutLine(sessionId: String, cwd: String?, line: Data) -> IngestResult {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
        else { return .ignored }
        // rollout 行形如 {"timestamp":...,"type":"event_msg","payload":{"type":"task_started",...}}
        let inner = obj["payload"] as? [String: Any] ?? obj
        guard let name = inner["type"] as? String else { return .ignored }
        if name == "token_count", let (metrics, limits) = parseCodexTokenCount(inner) {
            return .metrics(sessionId: sessionId, kind: .codex, metrics, limits)
        }
        var tool = inner["name"] as? String
        var detail = (inner["command"] as? String) ?? (inner["tool"] as? String) ?? tool
        // function_call 的 arguments 是 JSON 字符串,exec_command 从中提取命令文本
        if tool == "exec_command",
           let args = inner["arguments"] as? String,
           let parsed = (try? JSONSerialization.jsonObject(with: Data(args.utf8))) as? [String: Any],
           let command = parsed["command"] as? String {
            detail = command
        }
        if name == "web_search_call" || name == "tool_search_call" { tool = tool ?? name }
        return .event(AgentEvent(sessionId: sessionId, kind: .codex, cwd: cwd,
                                 name: name, detail: detail, tool: tool))
    }

    /// token_count 事件:last_token_usage 是最近一次请求的规模(≈ 当前 context 占用),
    /// model_context_window 是窗口大小,rate_limits 是账号级限额(primary=5小时/secondary=周)
    static func parseCodexTokenCount(_ p: [String: Any]) -> (Metrics, RateLimits?)? {
        guard let info = p["info"] as? [String: Any] else { return nil }
        var m = Metrics()
        if let last = info["last_token_usage"] as? [String: Any],
           let total = intValue(last["total_tokens"]), total > 0 {
            m.totalTokens = total
            if let window = intValue(info["model_context_window"]), window > 0 {
                m.contextPct = min(100, total * 100 / window)
            }
        } else if let total = info["total_token_usage"] as? [String: Any] {
            m.totalTokens = intValue(total["total_tokens"])
        }
        var limits: RateLimits?
        if let r = p["rate_limits"] as? [String: Any] {
            var l = RateLimits()
            if let w = r["primary"] as? [String: Any] { l.fiveHourPct = intValue(w["used_percent"]) }
            if let w = r["secondary"] as? [String: Any] { l.sevenDayPct = intValue(w["used_percent"]) }
            if l.fiveHourPct != nil || l.sevenDayPct != nil { limits = l }
        }
        guard m.totalTokens != nil || limits != nil else { return nil }
        return (m, limits)
    }
}
