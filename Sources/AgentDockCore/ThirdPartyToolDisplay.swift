import Foundation

// [skill: dev-dna] 按用户偏好：纯函数解析 + 短展示名，UI 层只消费 label
/// 把 MCP / 第三方工具事件收成短展示名（如 `notion/search`）。
/// 非第三方工具返回 nil。
public enum ThirdPartyToolDisplay {
    private static let mcpWrappers: Set<String> = [
        "CallMcpTool", "FetchMcpResource", "ListMcpResources", "GetMcpTools"
    ]

    /// - Parameters:
    ///   - tool: 工具本名（如 `CallMcpTool` / `mcp__notion__search`）
    ///   - detail: 事件 detail（ingest 后 ideally 为 `server/tool`）
    public static func label(tool: String?, detail: String?) -> String? {
        if let tool, mcpWrappers.contains(tool) {
            if let detail, !detail.isEmpty, detail != tool {
                return formatCombined(detail)
            }
            return nil
        }
        if let tool, tool.hasPrefix("mcp__") {
            return formatDunder(tool)
        }
        if let tool, tool.hasPrefix("mcp_") {
            let rest = String(tool.dropFirst(4))
            guard !rest.isEmpty else { return nil }
            return shortenServer(rest)
        }
        // Codex mcp_tool_call_begin：tool 可能是具体 MCP 名，也可能只有 detail
        if let detail, !detail.isEmpty, looksLikeThirdParty(detail) {
            return formatCombined(detail)
        }
        if let tool, looksLikeThirdParty(tool) {
            return formatCombined(tool)
        }
        return nil
    }

    /// 从 hook 的 tool_input 抽出 `server/tool`，供 ingest 写入 detail。
    public static func detailFromInput(_ input: [String: Any]?, tool: String?) -> String? {
        guard let input else { return nil }
        let server = (input["server"] as? String)
            ?? (input["mcpServer"] as? String)
            ?? (input["mcp_server"] as? String)
        let name = (input["toolName"] as? String)
            ?? (input["tool_name"] as? String)
            ?? (input["name"] as? String)
            ?? (input["uri"] as? String)
        if let server, !server.isEmpty, let name, !name.isEmpty {
            return "\(server)/\(name)"
        }
        if let server, !server.isEmpty { return server }
        if let name, !name.isEmpty, tool.map(mcpWrappers.contains) == true {
            return name
        }
        return nil
    }

    // MARK: - private

    private static func looksLikeThirdParty(_ s: String) -> Bool {
        s.hasPrefix("mcp_") || s.hasPrefix("mcp__") || s.contains("/")
    }

    private static func formatDunder(_ tool: String) -> String? {
        // mcp__server__tool… → server/tool…
        let parts = tool.split(separator: "__", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, parts[0] == "mcp" else { return shortenServer(tool) }
        let server = shortenServer(parts[1])
        let name = parts[2...].joined(separator: "__")
        guard !server.isEmpty, !name.isEmpty else { return nil }
        return "\(server)/\(name)"
    }

    private static func formatCombined(_ raw: String) -> String {
        if let slash = raw.firstIndex(of: "/") {
            let server = shortenServer(String(raw[..<slash]))
            let name = String(raw[raw.index(after: slash)...])
            if server.isEmpty { return name }
            if name.isEmpty { return server }
            return "\(server)/\(name)"
        }
        if raw.hasPrefix("mcp__") { return formatDunder(raw) ?? raw }
        return shortenServer(raw)
    }

    /// 压缩 marketplace / plugin 风格的 server id，避免撑爆任务名行。
    public static func shortenServer(_ raw: String) -> String {
        var s = raw
        for prefix in ["plugin-", "cursor-", "user-"] {
            if s.lowercased().hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
            }
        }
        for suffix in ["-mcp", "-server", "-workspace"] {
            if s.lowercased().hasSuffix(suffix) {
                s = String(s.dropLast(suffix.count))
            }
        }
        let tokens = s.split(separator: "-").map(String.init)
        if tokens.count == 2, tokens[0].lowercased() == tokens[1].lowercased() {
            return tokens[0]
        }
        if s.count > 18, let last = tokens.last, !last.isEmpty {
            return last
        }
        return s
    }
}
