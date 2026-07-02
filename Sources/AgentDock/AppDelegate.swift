import AppKit
import SwiftUI
import AgentDockCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = SessionStore()
    private var server: SocketServer?
    private var codexTailer: CodexSessionTailer?
    private var notchWindow: NotchWindow?
    private var pruneTimer: Timer?
    private var statusItem: NSStatusItem?

    static let home = NSHomeDirectory()
    static let socketPath = home + "/.agentdock/agentdock.sock"
    static let emitInstallPath = home + "/.agentdock/agentdock-emit"

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEmitScript()
        startServer()
        startCodexTailer()
        setupStatusItem()

        notchWindow = NotchWindow(store: store)
        notchWindow?.show()

        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.prune() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        codexTailer?.stop()
    }

    // MARK: - 采集

    private func startServer() {
        let server = SocketServer(path: Self.socketPath) { line in
            let result = EventIngestor.parseLine(line)
            Task { @MainActor [weak self] in self?.store.apply(result) }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            NSLog("AgentDock: socket server failed to start: \(error)")
        }
    }

    private func startCodexTailer() {
        let root = Self.home + "/.codex/sessions"
        guard FileManager.default.fileExists(atPath: root) else { return }
        let tailer = CodexSessionTailer(root: root) { sessionId, line in
            let result = EventIngestor.parseCodexRolloutLine(sessionId: sessionId, cwd: nil, line: line)
            Task { @MainActor [weak self] in self?.store.apply(result) }
        }
        tailer.start()
        codexTailer = tailer
    }

    /// 把 bundle 里的 agentdock-emit 复制到固定路径(hooks 配置引用它)
    private func installEmitScript() {
        guard let src = CoreResources.emitScriptPath else { return }
        let fm = FileManager.default
        try? fm.createDirectory(atPath: (Self.emitInstallPath as NSString).deletingLastPathComponent,
                                withIntermediateDirectories: true)
        try? fm.removeItem(atPath: Self.emitInstallPath)
        try? fm.copyItem(atPath: src, toPath: Self.emitInstallPath)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.emitInstallPath)
    }

    // MARK: - 菜单栏(安装/卸载入口)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "AgentDock")
        let menu = NSMenu()
        menu.addItem(withTitle: "安装 Claude Code 集成", action: #selector(installClaude), keyEquivalent: "")
        menu.addItem(withTitle: "卸载 Claude Code 集成", action: #selector(uninstallClaude), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "安装 Codex 集成", action: #selector(installCodex), keyEquivalent: "")
        menu.addItem(withTitle: "卸载 Codex 集成", action: #selector(uninstallCodex), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 AgentDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for i in menu.items where i.action != #selector(NSApplication.terminate(_:)) { i.target = self }
        item.menu = menu
        statusItem = item
    }

    private var claudeInstaller: ClaudeInstaller {
        ClaudeInstaller(settingsPath: Self.home + "/.claude/settings.json",
                        emitPath: Self.emitInstallPath)
    }
    private var codexInstaller: CodexInstaller {
        CodexInstaller(configPath: Self.home + "/.codex/config.toml",
                       emitPath: Self.emitInstallPath)
    }

    @objc private func installClaude() { runInstall { try self.claudeInstaller.install() } }
    @objc private func uninstallClaude() { runInstall { try self.claudeInstaller.uninstall() } }
    @objc private func installCodex() { runInstall { try self.codexInstaller.install() } }
    @objc private func uninstallCodex() { runInstall { try self.codexInstaller.uninstall() } }

    private func runInstall(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            let alert = NSAlert()
            alert.messageText = "操作失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
