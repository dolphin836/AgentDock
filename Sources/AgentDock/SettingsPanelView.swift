import SwiftUI
import AppKit
import Carbon.HIToolbox
import AgentDockCore

extension Notification.Name {
    /// 快捷键录制开始/结束:期间需暂停全局热键,避免按下的组合被热键吞掉
    static let agentDockHotkeyRecordingBegan = Notification.Name("AgentDockHotkeyRecordingBegan")
    static let agentDockHotkeyRecordingEnded = Notification.Name("AgentDockHotkeyRecordingEnded")
}

/// 面板内的「设置」tab:与会话列表同一套终端风格(等宽网格 + 结构线分区)
struct SettingsPanelView: View {
    @Bindable var settings: AppSettings
    @State private var integrationsRefresh = 0
    @State private var permissionsRefresh = 0
    @State private var updateStatus: UpdateStatus = .idle

    enum UpdateStatus: Equatable {
        case idle, checking, upToDate, failed
        case available(UpdateInfo)
    }
    /// 设置页可见期间周期性复查权限/集成状态(用户可能刚在系统设置里授权完回来)
    private let statusPoll = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private static let home = NSHomeDirectory()
    private static let emitPath = home + "/.agentdock/agentdock-emit"

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionRule(settings.t("GENERAL", "通用"))
            languageRow
            launchAtLoginRow
            displayRow

            sectionRule(settings.t("SHORTCUTS", "快捷键"))
            HotkeyRow(label: settings.t("show/hide panel", "面板展开/收起"),
                      hotkey: $settings.toggleHotkey)
            HotkeyRow(label: settings.t("approve (when pending)", "审批·允许(有待审批时)"),
                      hotkey: $settings.allowHotkey)
            HotkeyRow(label: settings.t("deny (when pending)", "审批·拒绝(有待审批时)"),
                      hotkey: $settings.denyHotkey)

            sectionRule(settings.t("INTEGRATIONS", "集成"))
            Group {
                integrationRow("CLAUDE CODE", ClaudeInstaller(
                    settingsPath: Self.home + "/.claude/settings.json", emitPath: Self.emitPath))
                integrationRow("CODEX", CodexInstaller(
                    configPath: Self.home + "/.codex/config.toml", emitPath: Self.emitPath))
                integrationRow("CURSOR", CursorInstaller(
                    hooksPath: Self.home + "/.cursor/hooks.json", emitPath: Self.emitPath))
            }
            .id(integrationsRefresh)

            sectionRule(settings.t("PERMISSIONS", "系统权限"))
            Group {
                automationRow(name: "Terminal", bundleId: "com.apple.Terminal")
                automationRow(name: "iTerm2", bundleId: "com.googlecode.iterm2")
                accessibilityRow
            }
            .id(permissionsRefresh)

            sectionRule(settings.t("ABOUT", "关于"))
            HStack(spacing: 10) {
                Text(settings.t("version", "当前版本"))
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.text2)
                Text("v\(AppInfo.version)")
                    .font(Theme.mono(10, .semibold))
                    .foregroundStyle(Theme.text1)
                Spacer()
                switch updateStatus {
                case .idle:
                    EmptyView()
                case .checking:
                    Text(settings.t("checking…", "检查中…"))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.text3)
                case .upToDate:
                    Text(settings.t("up to date", "已是最新版本"))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.text3)
                case .failed:
                    Text(settings.t("check failed", "检查失败"))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.text4)
                case .available(let info):
                    Text(settings.t("new version v\(info.version)", "发现新版本 v\(info.version)"))
                        .font(Theme.mono(9, .semibold))
                        .foregroundStyle(Theme.amber)
                }
                if case .available(let info) = updateStatus {
                    TermButton(title: settings.t("UPDATE", "立即更新"), color: Theme.amber.opacity(0.9)) {
                        if let url = URL(string: info.download) { NSWorkspace.shared.open(url) }
                    }
                } else {
                    TermButton(title: settings.t("CHECK UPDATES", "检查更新"), color: Theme.phosphor.opacity(0.85)) {
                        checkForUpdates()
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)

            linkRow(label: settings.t("website", "官网"),
                    title: "agentdockstatus.app",
                    url: "https://www.agentdockstatus.app")
            linkRow(label: settings.t("more apps", "更多应用"),
                    title: "Wallpaper Exchange · wallpaperexchange.com",
                    url: "https://www.wallpaperexchange.com")

            HStack {
                Spacer()
                TermButton(title: settings.t("QUIT AGENTDOCK", "退出 AgentDock"),
                           color: Theme.red.opacity(0.8)) {
                    AppQuit.quit()
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .onAppear {
            permissionsRefresh += 1
            integrationsRefresh += 1
            launchAtLogin = LaunchAtLogin.isEnabled
            checkForUpdates()
        }
        .onReceive(statusPoll) { _ in
            permissionsRefresh += 1
            integrationsRefresh += 1
        }
    }

    // MARK: 检查更新

    /// 拉官网 version.json 与当前版本比较;已发现新版后不再重复检查(避免覆盖提示)
    private func checkForUpdates() {
        if case .available = updateStatus { return }
        updateStatus = .checking
        Task {
            do {
                let info = try await UpdateChecker.fetchLatest()
                updateStatus = UpdateChecker.isNewer(info.version, than: AppInfo.version)
                    ? .available(info) : .upToDate
            } catch {
                updateStatus = .failed
            }
        }
    }

    // MARK: 通用

    private var languageRow: some View {
        HStack(spacing: 8) {
            Text(settings.t("language", "语言"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Spacer()
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                selectable(lang.displayName, active: settings.language == lang) {
                    settings.language = lang
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            Text(settings.t("launch at login", "开机自启"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Spacer()
            selectable(launchAtLogin ? settings.t("on", "开启") : settings.t("off", "关闭"),
                       active: launchAtLogin) {
                do {
                    try LaunchAtLogin.setEnabled(!launchAtLogin)
                    launchAtLogin = LaunchAtLogin.isEnabled
                } catch {
                    NSApp.activate(ignoringOtherApps: true)
                    NSAlert(error: error).runModal()
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    private var displayRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(settings.t("display", "展示屏幕"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                selectable(settings.t("main display (default)", "主屏(默认)"),
                           active: settings.displayID == nil) {
                    settings.displayID = nil
                }
                ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                    if let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue {
                        selectable("\(index + 1): \(screen.localizedName)",
                                   active: settings.displayID == id) {
                            settings.displayID = id
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    /// 单选项:● 选中(磷光绿)/ ○ 未选
    private func selectable(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(active ? "●" : "○")
                    .font(Theme.mono(8))
                    .foregroundStyle(active ? Theme.phosphor : Theme.text4)
                Text(title)
                    .font(Theme.mono(10))
                    .foregroundStyle(active ? Theme.text1 : Theme.text3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 集成

    private func integrationRow(_ name: String, _ installer: some AgentIntegrationInstaller) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(Theme.mono(10, .semibold))
                .tracking(1)
                .foregroundStyle(Theme.text2)
            Text(installer.isInstalled
                 ? settings.t("installed", "已安装")
                 : settings.t("not installed", "未安装"))
                .font(Theme.mono(9))
                .foregroundStyle(installer.isInstalled ? Theme.phosphor.opacity(0.8) : Theme.text4)
            Spacer()
            TermButton(title: installer.isInstalled
                       ? settings.t("UNINSTALL", "卸载")
                       : settings.t("INSTALL", "安装"),
                       color: installer.isInstalled ? Theme.red.opacity(0.8) : Theme.phosphor.opacity(0.85)) {
                do {
                    installer.isInstalled ? try installer.uninstall() : try installer.install()
                } catch {
                    // 面板是非激活窗口,不先激活 App 弹窗会沉底
                    NSApp.activate(ignoringOtherApps: true)
                    NSAlert(error: error).runModal()
                }
                integrationsRefresh += 1
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    // MARK: 系统权限

    /// 「自动化」:点击会话时精确选中 Terminal/iTerm2 的 tab;不授权则退化为激活 App
    private func automationRow(name: String, bundleId: String) -> some View {
        let status = PermissionGuide.automationStatus(bundleId: bundleId)
        return HStack(spacing: 10) {
            Text(settings.t("automation · \(name)", "自动化 · \(name)"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Text(automationStatusText(status))
                .font(Theme.mono(9))
                .foregroundStyle(automationStatusColor(status))
            Spacer()
            switch status {
            case .notDetermined:
                TermButton(title: settings.t("REQUEST", "请求授权"),
                           color: Theme.phosphor.opacity(0.85)) {
                    _ = PermissionGuide.automationStatus(bundleId: bundleId, askIfNeeded: true)
                    permissionsRefresh += 1
                }
            case .denied:
                TermButton(title: settings.t("SYSTEM SETTINGS", "系统设置"),
                           color: Theme.amber.opacity(0.85)) {
                    PermissionGuide.openAutomationSettings()
                }
            case .granted, .notRunning:
                EmptyView()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    /// 「辅助功能」:Codex/Cursor 辅助代答需要合成审批按键
    private var accessibilityRow: some View {
        let granted = PermissionGuide.accessibilityGranted()
        return HStack(spacing: 10) {
            Text(settings.t("accessibility", "辅助功能"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Text(granted ? settings.t("granted", "已授权") : settings.t("not granted", "未授权"))
                .font(Theme.mono(9))
                .foregroundStyle(granted ? Theme.phosphor.opacity(0.8) : Theme.text4)
            Spacer()
            if !granted {
                TermButton(title: settings.t("REQUEST", "请求授权"),
                           color: Theme.phosphor.opacity(0.85)) {
                    _ = PermissionGuide.accessibilityGranted(promptIfNeeded: true)
                    permissionsRefresh += 1
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    private func automationStatusText(_ status: PermissionGuide.Status) -> String {
        switch status {
        case .granted: settings.t("granted", "已授权")
        case .denied: settings.t("denied", "已拒绝")
        case .notDetermined: settings.t("not asked", "尚未询问")
        case .notRunning: settings.t("app not running", "未运行")
        }
    }

    private func automationStatusColor(_ status: PermissionGuide.Status) -> Color {
        switch status {
        case .granted: Theme.phosphor.opacity(0.8)
        case .denied: Theme.red.opacity(0.8)
        case .notDetermined, .notRunning: Theme.text4
        }
    }

    /// 外链行:标签 + 可点击的链接文本(hover 变磷光绿)
    private func linkRow(label: String, title: String, url: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Spacer()
            Button {
                if let target = URL(string: url) { NSWorkspace.shared.open(target) }
            } label: {
                Text(title)
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.cyan.opacity(0.85))
                    .underline(true, color: Theme.cyan.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    // MARK: 结构线(与会话列表分组样式一致)

    private func sectionRule(_ title: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Theme.text3.opacity(0.35))
                .frame(width: 12, height: 1)
            Text(title)
                .font(Theme.mono(9, .semibold))
                .tracking(1.6)
                .foregroundStyle(Theme.text3.opacity(0.85))
            Rectangle()
                .fill(Theme.text3.opacity(0.18))
                .frame(height: 1)
        }
        .padding(.horizontal, 9)
        .padding(.top, 9)
        .padding(.bottom, 4)
    }
}

/// 统一三家安装器的最小接口(仅设置页使用)
protocol AgentIntegrationInstaller {
    var isInstalled: Bool { get }
    func install() throws
    func uninstall() throws
}

extension ClaudeInstaller: AgentIntegrationInstaller {}
extension CodexInstaller: AgentIntegrationInstaller {}
extension CursorInstaller: AgentIntegrationInstaller {}

/// 快捷键行:点击键帽进入录制,按下新组合(必须含修饰键)生效,Esc 取消
private struct HotkeyRow: View {
    let label: String
    @Binding var hotkey: Hotkey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            Spacer()
            Button {
                recording ? stop() : start()
            } label: {
                if recording {
                    Text("␣ …")
                        .font(Theme.mono(9, .semibold))
                        .foregroundStyle(Theme.yellow)
                        .padding(.horizontal, 4)
                } else {
                    Keycaps(keys: hotkey.keycaps)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
    }

    private func start() {
        recording = true
        NotificationCenter.default.post(name: .agentDockHotkeyRecordingBegan, object: nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stop() }
            if event.keyCode == UInt16(kVK_Escape) { return nil }
            guard let chars = event.charactersIgnoringModifiers?.uppercased(),
                  let first = chars.first else { return nil }
            var mods = 0
            var symbols = ""
            if event.modifierFlags.contains(.control) { mods |= controlKey; symbols += "⌃" }
            if event.modifierFlags.contains(.option) { mods |= optionKey; symbols += "⌥" }
            if event.modifierFlags.contains(.shift) { mods |= shiftKey; symbols += "⇧" }
            if event.modifierFlags.contains(.command) { mods |= cmdKey; symbols += "⌘" }
            guard mods != 0 else { return nil }  // 全局快捷键必须带修饰键
            let keyText = event.keyCode == UInt16(kVK_Space) ? "␣" : String(first)
            hotkey = Hotkey(keyCode: Int(event.keyCode), modifiers: mods,
                            display: symbols + keyText)
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        NotificationCenter.default.post(name: .agentDockHotkeyRecordingEnded, object: nil)
    }
}
