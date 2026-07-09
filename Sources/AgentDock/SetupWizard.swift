import SwiftUI
import AppKit
import AgentDockCore

/// 首次启动的安装设置向导:pkg 装完自动启动 App 时弹出,分步完成
/// 语言 → 开机自启 → Agent 集成 → 系统权限。完成后不再出现。
@MainActor
enum SetupWizard {
    static let doneKey = "AgentDockSetupDone"
    private static var window: NSWindow?

    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        // 安装器已预配置(语言/自启/集成):精简向导,只做必须在 GUI 里完成的权限授权
        let preconfigured = UserDefaults.standard.bool(forKey: SetupCLI.preconfiguredKey)
        show(preconfigured: preconfigured)
    }

    static func show(preconfigured: Bool = false) {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.backgroundColor = .black
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SetupWizardView(preconfigured: preconfigured) {
                UserDefaults.standard.set(true, forKey: doneKey)
                window?.orderOut(nil)
            })
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SetupWizardView: View {
    /// 安装器已预配置时,向导只保留「已就绪总结 + 权限授权」两步
    var preconfigured = false
    let onFinish: () -> Void
    @Bindable private var settings = AppSettings.shared
    @State private var step = 0
    @State private var launchAtLogin = true
    @State private var refresh = 0

    private static let home = NSHomeDirectory()
    private static let emitPath = home + "/.agentdock/agentdock-emit"

    private enum Step { case summary, language, autostart, keepAwake, integrations, permissions }

    private var steps: [Step] {
        preconfigured
            ? [.summary, .permissions]
            : [.language, .autostart, .keepAwake, .integrations, .permissions]
    }
    private var totalSteps: Int { steps.count }
    private var current: Step { steps[min(step, steps.count - 1)] }

    private func title(for s: Step) -> String {
        switch s {
        case .summary: settings.t("Ready", "已就绪")
        case .language: settings.t("Language", "语言")
        case .autostart: settings.t("Launch at Login", "开机自启")
        case .keepAwake: settings.t("Keep Awake", "防休眠")
        case .integrations: settings.t("Integrations", "Agent 集成")
        case .permissions: settings.t("Permissions", "系统权限")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Theme.text4.opacity(0.5)).frame(height: 1)

            Group {
                switch current {
                case .summary: summaryStep
                case .language: languageStep
                case .autostart: autostartStep
                case .keepAwake: keepAwakeStep
                case .integrations: integrationsStep
                case .permissions: permissionsStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)

            Rectangle().fill(Theme.text4.opacity(0.5)).frame(height: 1)
            footer
        }
        .background(Color.black)
        .frame(width: 540, height: 460)
    }

    // MARK: 头部:品牌 + 步骤指示

    private var header: some View {
        HStack(spacing: 10) {
            RobotGlyph(size: 20)
            Text(settings.t("AGENTDOCK SETUP", "AGENTDOCK 安装设置"))
                .font(Theme.mono(13, .bold))
                .tracking(2)
                .foregroundStyle(Theme.text1)
            Spacer()
            // 步骤点:当前磷光绿,已完成暗绿,未到暗灰
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Theme.phosphor
                              : index < step ? Theme.phosphor.opacity(0.35) : Theme.text4)
                        .frame(width: 6, height: 6)
                }
            }
            Text(settings.t("step \(step + 1)/\(totalSteps)", "第 \(step + 1)/\(totalSteps) 步"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 14)
    }

    // MARK: 预配置总结(安装器已配好时的首屏)

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeading(settings.t("You're set up", "已为你配置好"),
                        settings.t("The installer configured AgentDock with sensible defaults. You can change any of these later in Settings.",
                                   "安装器已用推荐默认值配置好 AgentDock,以下各项之后都能在「设置」里改。"))
            summaryLine(settings.t("Language", "语言"),
                        settings.language.displayName)
            summaryLine(settings.t("Launch at login", "开机自启"),
                        LaunchAtLogin.isEnabled ? settings.t("on", "开启") : settings.t("off", "关闭"))
            summaryLine(settings.t("Keep awake while agents run", "任务进行中防休眠"),
                        settings.keepAwakeWhileRunning ? settings.t("on", "开启") : settings.t("off", "关闭"))
            summaryLine(settings.t("Integrations", "Agent 集成"),
                        installedIntegrationsText)
            Text(settings.t("One optional step left: system permission.", "还剩一步可选的系统权限授权。"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text3)
                .padding(.top, 4)
        }
    }

    private var installedIntegrationsText: String {
        let installed = SetupCLI.detectInstalledAgents().filter { name in
            switch name {
            case "claude": ClaudeInstaller(settingsPath: Self.home + "/.claude/settings.json",
                                           emitPath: Self.emitPath).isInstalled
            case "codex": CodexInstaller(configPath: Self.home + "/.codex/config.toml",
                                         emitPath: Self.emitPath).isInstalled
            case "cursor": CursorInstaller(hooksPath: Self.home + "/.cursor/hooks.json",
                                           emitPath: Self.emitPath).isInstalled
            default: false
            }
        }
        guard !installed.isEmpty else { return settings.t("none detected", "未检测到") }
        return installed.map { $0.uppercased() }.joined(separator: " · ")
    }

    private func summaryLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text("●").font(Theme.mono(9)).foregroundStyle(Theme.phosphor.opacity(0.7))
            Text(label).font(Theme.mono(11)).foregroundStyle(Theme.text2)
            Spacer()
            Text(value).font(Theme.mono(11, .semibold)).foregroundStyle(Theme.text1)
        }
        .padding(.vertical, 3)
    }

    // MARK: 步骤 1:语言

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeading(title(for: .language), settings.t("Choose the interface language.", "选择界面语言。"))
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                bigOption(lang.displayName, active: settings.language == lang) {
                    settings.language = lang
                }
            }
        }
    }

    // MARK: 步骤 2:开机自启

    private var autostartStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeading(title(for: .autostart),
                        settings.t("Start AgentDock automatically when you log in.",
                                   "登录时自动启动 AgentDock,agent 状态随时可见。"))
            bigOption(settings.t("Enable (recommended)", "开启(推荐)"), active: launchAtLogin) {
                launchAtLogin = true
            }
            bigOption(settings.t("Not now", "暂不开启"), active: !launchAtLogin) {
                launchAtLogin = false
            }
        }
    }

    // MARK: 步骤 3:防休眠

    private var keepAwakeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeading(title(for: .keepAwake),
                        settings.t("Prevent your Mac from idle-sleeping while an agent task is running, so long tasks don't get suspended midway.",
                                   "Agent 任务进行中阻止 Mac 闲置休眠,长任务不会跑到一半被挂起。"))
            bigOption(settings.t("Enable (recommended)", "开启(推荐)"),
                      active: settings.keepAwakeWhileRunning) {
                settings.keepAwakeWhileRunning = true
            }
            bigOption(settings.t("Not now", "暂不开启"),
                      active: !settings.keepAwakeWhileRunning) {
                settings.keepAwakeWhileRunning = false
            }
            Text(settings.t("Only active while a task is running; released the moment all agents go idle. Does not affect lid-close sleep.",
                            "仅在有任务运行时生效,全部空闲立即释放;不影响合盖休眠。"))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text4)
        }
    }

    // MARK: 步骤 4:集成

    private var integrationsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepHeading(title(for: .integrations),
                        settings.t("Register the event emitter into each agent for sub-second status and in-panel approvals.",
                                   "把事件发射器注册进各 agent,获得亚秒级状态与面板内审批。"))
            Group {
                wizardIntegrationRow("CLAUDE CODE", ClaudeInstaller(
                    settingsPath: Self.home + "/.claude/settings.json", emitPath: Self.emitPath))
                wizardIntegrationRow("CODEX", CodexInstaller(
                    configPath: Self.home + "/.codex/config.toml", emitPath: Self.emitPath))
                wizardIntegrationRow("CURSOR", CursorInstaller(
                    hooksPath: Self.home + "/.cursor/hooks.json", emitPath: Self.emitPath))
            }
            .id(refresh)
            Text(settings.t("Uninstalling later only removes AgentDock's own entries.",
                            "以后卸载只会移除 AgentDock 自己的配置条目。"))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text4)
        }
    }

    private func wizardIntegrationRow(_ name: String,
                                      _ installer: some AgentIntegrationInstaller) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(Theme.mono(11, .semibold))
                .tracking(1)
                .foregroundStyle(Theme.text1)
            Text(installer.isInstalled
                 ? settings.t("installed", "已安装")
                 : settings.t("not installed", "未安装"))
                .font(Theme.mono(10))
                .foregroundStyle(installer.isInstalled ? Theme.phosphor.opacity(0.8) : Theme.text4)
            Spacer()
            TermButton(title: installer.isInstalled
                       ? settings.t("UNINSTALL", "卸载")
                       : settings.t("INSTALL", "安装"),
                       color: installer.isInstalled ? Theme.red.opacity(0.8) : Theme.phosphor.opacity(0.85)) {
                do {
                    installer.isInstalled ? try installer.uninstall() : try installer.install()
                } catch {
                    NSAlert(error: error).runModal()
                }
                refresh += 1
            }
        }
        .padding(.vertical, 5)
    }

    // MARK: 步骤 5:权限

    private var permissionsStep: some View {
        let granted = PermissionGuide.accessibilityGranted()
        return VStack(alignment: .leading, spacing: 14) {
            stepHeading(title(for: .permissions),
                        settings.t("Optional system permissions.", "可选的系统权限,跳过不影响核心功能。"))
            HStack(spacing: 10) {
                Text(settings.t("Accessibility", "辅助功能"))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.text1)
                Text(granted ? settings.t("granted", "已授权") : settings.t("not granted", "未授权"))
                    .font(Theme.mono(10))
                    .foregroundStyle(granted ? Theme.phosphor.opacity(0.8) : Theme.text4)
                Spacer()
                if !granted {
                    TermButton(title: settings.t("REQUEST", "请求授权"),
                               color: Theme.phosphor.opacity(0.85)) {
                        _ = PermissionGuide.accessibilityGranted(promptIfNeeded: true)
                        refresh += 1
                    }
                }
            }
            .id(refresh)
            Text(settings.t("Used for assisted approve/deny of Codex/Cursor approvals from the panel.",
                            "用于在面板内对 Codex/Cursor 的审批请求做辅助代答(聚焦宿主并代按审批键)。"))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text4)
            Text(settings.t("\"Automation\" (jump to exact terminal tab) is requested on first use.",
                            "「自动化」权限(跳转到终端具体标签页)会在首次点击跳转时按需弹出,无需现在设置。"))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text4)
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refresh += 1  // 用户去系统设置授权完回来自动刷新
        }
    }

    // MARK: 通用组件

    private func stepHeading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.mono(14, .bold))
                .foregroundStyle(Theme.text1)
            Text(subtitle)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text3)
        }
        .padding(.bottom, 6)
    }

    private func bigOption(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(active ? "●" : "○")
                    .font(Theme.mono(11))
                    .foregroundStyle(active ? Theme.phosphor : Theme.text4)
                Text(title)
                    .font(Theme.mono(12, active ? .semibold : .regular))
                    .foregroundStyle(active ? Theme.text1 : Theme.text3)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(active ? Color.white.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(active ? Theme.phosphor.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                TermButton(title: settings.t("BACK", "上一步"), color: Theme.text2) {
                    step -= 1
                }
            }
            Spacer()
            TermButton(title: step == totalSteps - 1
                       ? settings.t("FINISH", "完成")
                       : settings.t("CONTINUE", "继续"),
                       color: Theme.phosphor) {
                if current == .autostart {
                    try? LaunchAtLogin.setEnabled(launchAtLogin)  // 离开自启步骤时落盘
                }
                if step == totalSteps - 1 {
                    onFinish()
                } else {
                    step += 1
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
