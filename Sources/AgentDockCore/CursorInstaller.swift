import Foundation

/// 把 agentdock-emit 注册进 ~/.cursor/hooks.json(用户级 Cursor hooks)。
/// hook stdin 自带 hook_event_name/conversation_id/workspace_roots,emit 原样透传即可。
/// 安装前备份原文件;卸载时只移除 AgentDock 的条目,保留用户自己的 hooks。
public struct CursorInstaller {
    public let hooksPath: String
    public let emitPath: String

    static let hookEvents = ["sessionStart", "beforeSubmitPrompt", "preToolUse",
                             "postToolUse", "postToolUseFailure",
                             "beforeShellExecution", "afterShellExecution",
                             "beforeMCPExecution", "afterMCPExecution",
                             "subagentStart", "subagentStop",
                             "stop", "sessionEnd"]

    public init(hooksPath: String, emitPath: String) {
        self.hooksPath = hooksPath
        self.emitPath = emitPath
    }

    /// 不加引号:emit 固定装在 ~/.agentdock 下(无空格),而 Cursor 对带转义引号的
    /// 命令会静默执行失败(实测),hook 就完全不触发了
    private var hookCommand: String { "\(emitPath) cursor hook" }

    public var isInstalled: Bool {
        guard let config = readConfig(),
              let hooks = config["hooks"] as? [String: Any] else { return false }
        return Self.hookEvents.allSatisfy { containsOurHook(hooks[$0]) }
    }

    public func install() throws {
        var config = readConfig() ?? [:]
        if FileManager.default.fileExists(atPath: hooksPath) {
            try? FileManager.default.removeItem(atPath: hooksPath + ".agentdock-backup")
            try FileManager.default.copyItem(atPath: hooksPath, toPath: hooksPath + ".agentdock-backup")
        }
        config["version"] = config["version"] ?? 1
        var hooks = config["hooks"] as? [String: Any] ?? [:]
        for event in Self.hookEvents where !containsOurHook(hooks[event]) {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.append(["command": hookCommand])
            hooks[event] = entries
        }
        config["hooks"] = hooks
        try writeConfig(config)
    }

    public func uninstall() throws {
        guard var config = readConfig(),
              var hooks = config["hooks"] as? [String: Any] else { return }
        for event in Self.hookEvents {
            guard var entries = hooks[event] as? [[String: Any]] else { continue }
            entries.removeAll { isOurEntry($0) }
            hooks[event] = entries.isEmpty ? nil : entries
        }
        config["hooks"] = hooks.compactMapValues { $0 }
        try writeConfig(config.compactMapValues { $0 })
    }

    private func containsOurHook(_ value: Any?) -> Bool {
        guard let entries = value as? [[String: Any]] else { return false }
        return entries.contains { isOurEntry($0) }
    }

    private func isOurEntry(_ entry: [String: Any]) -> Bool {
        (entry["command"] as? String)?.contains(emitPath) == true
    }

    private func readConfig() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: hooksPath) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func writeConfig(_ config: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(
            atPath: (hooksPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: hooksPath), options: .atomic)
    }
}
