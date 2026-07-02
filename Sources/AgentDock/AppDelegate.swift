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

        notchWindow = NotchWindow(store: store, settings: AppSettings.shared)
        notchWindow?.show()

        backfillSessions()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.prune()
                self?.backfillSessions()
            }
        }
    }

    /// 扫描磁盘 transcript,补上「启动前就存在、还没发过事件」的会话(CLI/桌面端/插件)
    private func backfillSessions() {
        let claudeRoot = Self.home + "/.claude/projects"
        let codexRoot = Self.home + "/.codex/sessions"
        var scanned = SessionBackfillScanner.scanClaude(projectsRoot: claudeRoot)
            + SessionBackfillScanner.scanCodex(root: codexRoot)
        // 新版 Codex 的会话状态在 SQLite 里,JSONL 只是旧版遗留
        if let db = CodexStateReader.findDatabase(codexRoot: Self.home + "/.codex") {
            scanned += CodexStateReader.recentThreads(dbPath: db)
                .filter { !SessionBackfillScanner.isHiddenPath($0.cwd) }
        }
        store.backfill(scanned)
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
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let t = AppSettings.shared.t
        let menu = NSMenu()
        menu.addItem(withTitle: t("Install Claude Code Integration", "安装 Claude Code 集成"),
                     action: #selector(installClaude), keyEquivalent: "")
        menu.addItem(withTitle: t("Uninstall Claude Code Integration", "卸载 Claude Code 集成"),
                     action: #selector(uninstallClaude), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: t("Install Codex Integration", "安装 Codex 集成"),
                     action: #selector(installCodex), keyEquivalent: "")
        menu.addItem(withTitle: t("Uninstall Codex Integration", "卸载 Codex 集成"),
                     action: #selector(uninstallCodex), keyEquivalent: "")
        menu.addItem(.separator())

        let langItem = NSMenuItem(title: t("Language", "语言"), action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let mi = NSMenuItem(title: lang.displayName, action: #selector(switchLanguage(_:)), keyEquivalent: "")
            mi.representedObject = lang.rawValue
            mi.state = AppSettings.shared.language == lang ? .on : .off
            mi.target = self
            langMenu.addItem(mi)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: t("Quit AgentDock", "退出 AgentDock"),
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for i in menu.items where i.action != #selector(NSApplication.terminate(_:)) { i.target = self }
        statusItem?.menu = menu
    }

    @objc private func switchLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = AppLanguage(rawValue: raw) else { return }
        AppSettings.shared.language = lang
        rebuildMenu()
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
            alert.messageText = AppSettings.shared.t("Operation failed", "操作失败")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
