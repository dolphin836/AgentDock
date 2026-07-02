import Foundation

/// 把 agentdock-emit 注册进 ~/.claude/settings.json 的 hooks + statusLine。
/// 安装前备份原文件;卸载时只移除 AgentDock 的条目并还原 statusLine。
public struct ClaudeInstaller {
    public let settingsPath: String
    public let emitPath: String
    /// 用户原 statusline 命令的备份位置(agentdock-emit 会透传其输出)
    public let originalStatuslinePath: String

    static let hookEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse",
                             "PostToolUse", "Notification", "Stop", "SessionEnd"]

    public init(settingsPath: String, emitPath: String,
                originalStatuslinePath: String = NSString(string: "~/.agentdock/original-statusline-command").expandingTildeInPath) {
        self.settingsPath = settingsPath
        self.emitPath = emitPath
        self.originalStatuslinePath = originalStatuslinePath
    }

    private var hookCommand: String { "\"\(emitPath)\" claude-code hook" }
    private var statuslineCommand: String { "\"\(emitPath)\" claude-code statusline" }
    private var permissionCommand: String { "\"\(emitPath)\" claude-code permission" }

    public var isInstalled: Bool {
        guard let settings = readSettings() else { return false }
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        return Self.hookEvents.allSatisfy { containsOurHook(hooks[$0]) }
    }

    public func install() throws {
        var settings = readSettings() ?? [:]
        // 备份
        if FileManager.default.fileExists(atPath: settingsPath) {
            try? FileManager.default.removeItem(atPath: settingsPath + ".agentdock-backup")
            try FileManager.default.copyItem(atPath: settingsPath, toPath: settingsPath + ".agentdock-backup")
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in Self.hookEvents where !containsOurHook(hooks[event]) {
            var matchers = hooks[event] as? [[String: Any]] ?? []
            matchers.append(["hooks": [["type": "command", "command": hookCommand]]])
            hooks[event] = matchers
        }
        // 权限审批:阻塞等待面板决策,55s 超时回落原生对话框
        if !containsOurHook(hooks["PermissionRequest"]) {
            var matchers = hooks["PermissionRequest"] as? [[String: Any]] ?? []
            matchers.append(["hooks": [[
                "type": "command", "command": permissionCommand, "timeout": 55,
            ]]])
            hooks["PermissionRequest"] = matchers
        }
        settings["hooks"] = hooks

        // statusLine:备份用户原命令供 emit 脚本透传,再替换
        if let existing = settings["statusLine"] as? [String: Any],
           let cmd = existing["command"] as? String, cmd != statuslineCommand {
            try FileManager.default.createDirectory(
                atPath: (originalStatuslinePath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            try cmd.write(toFile: originalStatuslinePath, atomically: true, encoding: .utf8)
        }
        settings["statusLine"] = ["type": "command", "command": statuslineCommand]

        try writeSettings(settings)
    }

    public func uninstall() throws {
        guard var settings = readSettings() else { return }
        if var hooks = settings["hooks"] as? [String: Any] {
            for event in Self.hookEvents + ["PermissionRequest"] {
                guard var matchers = hooks[event] as? [[String: Any]] else { continue }
                matchers.removeAll { isOurMatcher($0) }
                hooks[event] = matchers.isEmpty ? nil : matchers
            }
            settings["hooks"] = hooks.isEmpty ? nil : hooks
        }
        if let sl = settings["statusLine"] as? [String: Any],
           sl["command"] as? String == statuslineCommand {
            if let original = try? String(contentsOfFile: originalStatuslinePath, encoding: .utf8),
               !original.isEmpty {
                settings["statusLine"] = ["type": "command", "command": original]
                try? FileManager.default.removeItem(atPath: originalStatuslinePath)
            } else {
                settings["statusLine"] = nil
            }
        }
        try writeSettings(settings.compactMapValues { $0 })
    }

    private func containsOurHook(_ value: Any?) -> Bool {
        guard let matchers = value as? [[String: Any]] else { return false }
        return matchers.contains { isOurMatcher($0) }
    }

    private func isOurMatcher(_ matcher: [String: Any]) -> Bool {
        guard let inner = matcher["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { ($0["command"] as? String)?.contains(emitPath) == true }
    }

    private func readSettings() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: settingsPath) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try FileManager.default.createDirectory(
            atPath: (settingsPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
    }
}
