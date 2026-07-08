import Foundation

/// 向 ~/.codex/config.toml 写入/移除 notify 配置(文本级操作,不解析完整 TOML)。
/// Codex 的 notify 只允许一个程序:若用户已有 notify(如 Codex Desktop 的
/// Computer Use),生成链式转发脚本先调原程序再发 AgentDock,卸载时原样还原。
public struct CodexInstaller {
    public let configPath: String
    public let emitPath: String

    public init(configPath: String, emitPath: String) {
        self.configPath = configPath
        self.emitPath = emitPath
    }

    /// 链式转发脚本位置(与 emit 同目录)
    public var chainScriptPath: String {
        (emitPath as NSString).deletingLastPathComponent + "/codex-notify-chain"
    }

    private var directNotifyLine: String {
        #"notify = ["\#(emitPath)", "codex", "notify"] # agentdock"#
    }
    private var chainNotifyLine: String {
        #"notify = ["\#(chainScriptPath)"] # agentdock"#
    }
    static let preservedSuffix = "# agentdock-preserved"

    public var isInstalled: Bool {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return false }
        return text.split(separator: "\n").contains { $0.hasSuffix("# agentdock") }
    }

    public func install() throws {
        var text = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
        guard !isInstalled else { return }

        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let existingIndex = lines.firstIndex {
            $0.range(of: #"^\s*notify\s*="#, options: .regularExpression) != nil
                && !$0.hasSuffix("# agentdock") && !$0.hasSuffix(Self.preservedSuffix)
        }

        if let index = existingIndex {
            // 已有别家 notify:生成链式脚本,原行注释保存以便卸载还原
            guard let originalArgs = Self.parseNotifyArgs(lines[index]), !originalArgs.isEmpty else {
                throw NSError(domain: "AgentDock", code: 1, userInfo: [
                    NSLocalizedDescriptionKey:
                        "无法解析已有 notify 配置,请手动合并:\(directNotifyLine)"])
            }
            try writeChainScript(originalArgs: originalArgs)
            lines[index] = "# \(lines[index]) \(Self.preservedSuffix)"
            lines.append(chainNotifyLine)
            text = lines.joined(separator: "\n")
        } else {
            if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
            text += directNotifyLine + "\n"
        }

        try FileManager.default.createDirectory(
            atPath: (configPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try text.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    public func uninstall() throws {
        guard let text = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }
        let restored = text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasSuffix("# agentdock") }
            .map { line -> String in
                // 还原被注释保存的原 notify 行
                guard line.hasSuffix(Self.preservedSuffix) else { return String(line) }
                return String(line)
                    .replacingOccurrences(of: #"^#\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\s*\#(Self.preservedSuffix)$"#,
                                          with: "", options: .regularExpression)
            }
            .joined(separator: "\n")
        try restored.write(toFile: configPath, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(atPath: chainScriptPath)
    }

    /// 提取 notify = ["a", "b"] 的数组元素(支持 \" 与 \\ 转义)
    static func parseNotifyArgs(_ line: String) -> [String]? {
        guard let open = line.firstIndex(of: "["), let close = line.lastIndex(of: "]"),
              open < close else { return nil }
        let inner = String(line[line.index(after: open)..<close])
        let regex = try? NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
        guard let regex else { return nil }
        let range = NSRange(inner.startIndex..., in: inner)
        let args = regex.matches(in: inner, range: range).compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: inner) else { return nil }
            return String(inner[r])
                .replacingOccurrences(of: #"\""#, with: "\"")
                .replacingOccurrences(of: #"\\"#, with: "\\")
        }
        return args.isEmpty ? nil : args
    }

    private func writeChainScript(originalArgs: [String]) throws {
        let quoted = originalArgs.map { "'" + $0.replacingOccurrences(of: "'", with: #"'\''"#) + "'" }
        let script = """
        #!/bin/bash
        # AgentDock 链式 notify:先转发用户原有的 notify 程序,再发 AgentDock。
        # 任何失败都静默,绝不阻塞 Codex。由 AgentDock 安装器生成,卸载时删除。
        \(quoted.joined(separator: " ")) "$@" >/dev/null 2>&1 || true
        "\(emitPath)" codex notify "$@" >/dev/null 2>&1 || true
        exit 0
        """
        try FileManager.default.createDirectory(
            atPath: (chainScriptPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try script.write(toFile: chainScriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: chainScriptPath)
    }
}
