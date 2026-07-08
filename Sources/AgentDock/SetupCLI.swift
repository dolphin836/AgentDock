import AppKit
import AgentDockCore

/// 无头安装模式:`AgentDock --setup key=value ...`,供 install.sh 在安装时调用。
/// 支持的参数:
///   language=en|zh        默认语言
///   autostart=yes|no      开机自启(LaunchAgent)
///   integrations=claude,codex,cursor   要安装的集成
///   permissions=ask       触发「辅助功能」系统授权弹窗
@MainActor
enum SetupCLI {
    static let home = NSHomeDirectory()

    /// 命中 --setup 时执行并返回 true(调用方直接退出,不进入 GUI)
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard args.contains("--setup") else { return false }
        var options: [String: String] = [:]
        for arg in args where arg.contains("=") {
            let parts = arg.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { options[parts[0]] = parts[1] }
        }

        if let lang = options["language"] {
            let value = lang.hasPrefix("zh") ? "zh-Hans" : "en"
            UserDefaults.standard.set(value, forKey: "AgentDockLanguage")
            print("language: \(value)")
        }

        if let autostart = options["autostart"] {
            do {
                try LaunchAtLogin.setEnabled(autostart == "yes")
                print("autostart: \(autostart)")
            } catch {
                print("autostart: failed — \(error.localizedDescription)")
            }
        }

        if let integrations = options["integrations"], !integrations.isEmpty {
            installEmitScript()
            let emitPath = home + "/.agentdock/agentdock-emit"
            for name in integrations.split(separator: ",").map(String.init) {
                do {
                    switch name {
                    case "claude":
                        try ClaudeInstaller(settingsPath: home + "/.claude/settings.json",
                                            emitPath: emitPath).install()
                    case "codex":
                        try CodexInstaller(configPath: home + "/.codex/config.toml",
                                           emitPath: emitPath).install()
                    case "cursor":
                        try CursorInstaller(hooksPath: home + "/.cursor/hooks.json",
                                            emitPath: emitPath).install()
                    default:
                        print("integration \(name): unknown, skipped")
                        continue
                    }
                    print("integration \(name): installed")
                } catch {
                    print("integration \(name): failed — \(error.localizedDescription)")
                }
            }
        }

        if options["permissions"] == "ask" {
            // 触发「辅助功能」授权弹窗(归属安装路径的二进制,GUI 运行时同一份授权)
            let granted = PermissionGuide.accessibilityGranted(promptIfNeeded: true)
            print("accessibility: \(granted ? "granted" : "prompted — grant in System Settings")")
        }

        print("setup done")
        return true
    }

    /// 把 bundle 里的 agentdock-emit 复制到 hooks 引用的固定路径
    static func installEmitScript() {
        guard let src = CoreResources.emitScriptPath else { return }
        let dst = home + "/.agentdock/agentdock-emit"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                withIntermediateDirectories: true)
        try? fm.removeItem(atPath: dst)
        try? fm.copyItem(atPath: src, toPath: dst)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst)
    }
}
