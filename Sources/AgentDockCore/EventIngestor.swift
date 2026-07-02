import Foundation

public enum IngestResult: Sendable, Equatable {
    case event(AgentEvent)
    case metrics(sessionId: String, Metrics)
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
        default:
            return .ignored
        }
    }

    private static func parseClaudeHook(_ p: [String: Any], appPath: String?) -> IngestResult {
        guard let sessionId = p["session_id"] as? String,
              let name = p["hook_event_name"] as? String
        else { return .ignored }
        // detail 优先取操作的文件名(展示价值最高),其次工具名/消息
        var detail = (p["tool_name"] as? String) ?? (p["message"] as? String)
        if let input = p["tool_input"] as? [String: Any],
           let filePath = input["file_path"] as? String, !filePath.isEmpty {
            detail = (filePath as NSString).lastPathComponent
        }
        return .event(AgentEvent(
            sessionId: sessionId, kind: .claudeCode,
            cwd: p["cwd"] as? String, name: name, detail: detail, appPath: appPath))
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
            if let pct = ctx["used_percentage"] as? Double { m.contextPct = Int(pct) }
            else if let pct = ctx["used_percentage"] as? Int { m.contextPct = pct }
            // 当前 context 内的 input+output token 数(/compact 后会重置)
            let input = ctx["total_input_tokens"] as? Int ?? 0
            let output = ctx["total_output_tokens"] as? Int ?? 0
            if input + output > 0 { m.totalTokens = input + output }
        }
        return .metrics(sessionId: sessionId, m)
    }

    private static func parseCodexNotify(_ p: [String: Any], appPath: String?) -> IngestResult {
        guard let name = p["type"] as? String else { return .ignored }
        let sessionId = (p["thread-id"] as? String) ?? (p["turn-id"] as? String) ?? "codex"
        return .event(AgentEvent(
            sessionId: sessionId, kind: .codex,
            cwd: p["cwd"] as? String, name: name,
            detail: p["last-assistant-message"] as? String, appPath: appPath))
    }

    /// 解析 Codex rollout JSONL 的一行(由 CodexSessionTailer 提供 sessionId/cwd 上下文)。
    public static func parseCodexRolloutLine(sessionId: String, cwd: String?, line: Data) -> IngestResult {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
        else { return .ignored }
        // rollout 行形如 {"timestamp":...,"type":"event_msg","payload":{"type":"task_started",...}}
        let inner = obj["payload"] as? [String: Any] ?? obj
        guard let name = inner["type"] as? String else { return .ignored }
        let detail = (inner["command"] as? String) ?? (inner["tool"] as? String)
        return .event(AgentEvent(sessionId: sessionId, kind: .codex, cwd: cwd, name: name, detail: detail))
    }
}
