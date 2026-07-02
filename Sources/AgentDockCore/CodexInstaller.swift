import Foundation

/// 向 ~/.codex/config.toml 写入/移除 notify 配置(文本级操作,不解析完整 TOML)。
public struct CodexInstaller {
    public let configPath: String
    public let emitPath: String

    public init(configPath: String, emitPath: String) {
        self.configPath = configPath
        self.emitPath = emitPath
    }

    private var notifyLine: String { #"notify = ["\#(emitPath)", "codex", "notify"] # agentdock"# }

    public var isInstalled: Bool {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return false }
        return text.contains("# agentdock")
    }

    public func install() throws {
        var text = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
        guard !isInstalled else { return }
        if text.range(of: #"^\s*notify\s*="#, options: .regularExpression) != nil ||
            text.range(of: #"\n\s*notify\s*="#, options: .regularExpression) != nil {
            throw NSError(domain: "AgentDock", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "config.toml 已有 notify 配置,请手动合并:\(notifyLine)"])
        }
        if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
        text += notifyLine + "\n"
        try FileManager.default.createDirectory(
            atPath: (configPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try text.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    public func uninstall() throws {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        let kept = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasSuffix("# agentdock") }
            .joined(separator: "\n")
        try kept.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}
