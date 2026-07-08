import Foundation
import AppKit
import Observation
import Carbon.HIToolbox
import AgentDockCore

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

/// 全局快捷键组合(Carbon keyCode + 修饰键),display 为 ⌘G 这样的展示串
struct Hotkey: Codable, Equatable {
    var keyCode: Int
    var modifiers: Int
    var display: String

    /// 键帽渲染用:["⌘", "G"]
    var keycaps: [String] { display.map(String.init) }
}

extension Notification.Name {
    static let agentDockOpenSettings = Notification.Name("AgentDockOpenSettings")
    static let agentDockDisplayChanged = Notification.Name("AgentDockDisplayChanged")
    static let agentDockHotkeysChanged = Notification.Name("AgentDockHotkeysChanged")
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "AgentDockLanguage") }
    }

    /// 展示屏幕的 displayID;nil = 跟随主屏(默认)
    var displayID: Int? {
        didSet {
            UserDefaults.standard.set(displayID ?? 0, forKey: "AgentDockDisplayID")
            NotificationCenter.default.post(name: .agentDockDisplayChanged, object: nil)
        }
    }

    var toggleHotkey: Hotkey {
        didSet { persist(toggleHotkey, key: "AgentDockHotkeyToggle") }
    }
    var allowHotkey: Hotkey {
        didSet { persist(allowHotkey, key: "AgentDockHotkeyAllow") }
    }
    var denyHotkey: Hotkey {
        didSet { persist(denyHotkey, key: "AgentDockHotkeyDeny") }
    }

    static let defaultToggle = Hotkey(keyCode: kVK_ANSI_G, modifiers: cmdKey, display: "⌘G")
    static let defaultAllow = Hotkey(keyCode: kVK_ANSI_Y, modifiers: cmdKey, display: "⌘Y")
    static let defaultDeny = Hotkey(keyCode: kVK_ANSI_N, modifiers: cmdKey, display: "⌘N")

    private init() {
        let defaults = UserDefaults.standard
        language = AppLanguage(rawValue: defaults.string(forKey: "AgentDockLanguage") ?? "") ?? .english
        let storedDisplay = defaults.integer(forKey: "AgentDockDisplayID")
        displayID = storedDisplay == 0 ? nil : storedDisplay
        toggleHotkey = Self.load(key: "AgentDockHotkeyToggle") ?? Self.defaultToggle
        allowHotkey = Self.load(key: "AgentDockHotkeyAllow") ?? Self.defaultAllow
        denyHotkey = Self.load(key: "AgentDockHotkeyDeny") ?? Self.defaultDeny
    }

    /// 面板/刘海条挂靠的屏幕:选定屏不在了(拔线)自动回落主屏
    var targetScreen: NSScreen? {
        guard let displayID else { return NSScreen.screens.first }
        return NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue == displayID
        } ?? NSScreen.screens.first
    }

    private func persist(_ hotkey: Hotkey, key: String) {
        if let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .agentDockHotkeysChanged, object: nil)
    }

    private static func load(key: String) -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Hotkey.self, from: data)
    }

    /// 双语文案:t(英文, 中文)
    func t(_ en: String, _ zh: String) -> String {
        language == .english ? en : zh
    }

    /// 与 CLI 用语一致的状态文案
    func label(for state: SessionState) -> String {
        switch state {
        case .idle: t("Idle", "空闲")
        case .thinking: t("Thinking…", "思考中…")
        case .runningTool: t("Running…", "执行中…")
        case .waitingInput: t("Waiting for input", "等待输入")
        case .waitingApproval: t("Needs approval", "需要审批")
        case .done: t("Done", "已完成")
        case .disconnected: t("Disconnected", "已断开")
        }
    }
}
