import AppKit
import ApplicationServices

/// AgentDock 的系统授权检查与引导。
///
/// 本地数据(~/.claude、~/.codex、~/.cursor 的 transcript/SQLite/注册表、同用户
/// 进程表)都是家目录普通文件与常规 syscall,**不需要**任何 TCC 授权。
/// 唯一需要用户批准的是「自动化」(Apple 事件):点击会话行、且宿主 App 未知时,
/// 用 AppleScript 匹配 Terminal/iTerm2 窗口。未授权时该路径退化为 Finder 定位,
/// 其他功能完全不受影响。
@MainActor
enum PermissionGuide {

    struct Target {
        let name: String
        let bundleId: String
    }

    /// TerminalJumper 会用 AppleScript 控制的目标
    static let automationTargets = [
        Target(name: "Terminal", bundleId: "com.apple.Terminal"),
        Target(name: "iTerm2", bundleId: "com.googlecode.iterm2"),
    ]

    enum Status {
        case granted
        case denied
        case notDetermined
        /// 目标 App 未运行,系统无法判定/弹框
        case notRunning
    }

    /// 无打扰查询;askIfNeeded = true 且目标在运行时会触发系统授权弹窗
    static func automationStatus(bundleId: String, askIfNeeded: Bool = false) -> Status {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleId)
        let err = AEDeterminePermissionToAutomateTarget(
            target.aeDesc, typeWildCard, typeWildCard, askIfNeeded)
        switch err {
        case noErr: return .granted
        case -1743: return .denied         // errAEEventNotPermitted
        case -1744: return .notDetermined  // errAEEventWouldRequireUserConsent
        case -600: return .notRunning      // procNotFound
        default: return .denied
        }
    }

    /// AppleScript 跳转是否值得尝试:denied 时直接跳过,避免必然失败;
    /// notDetermined 时照常尝试——系统弹出的授权框本身就是引导。
    static func mayUseAppleScript(bundleId: String) -> Bool {
        switch automationStatus(bundleId: bundleId) {
        case .denied: false
        default: true
        }
    }

    static func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    /// 「辅助功能」授权:Codex/Cursor 辅助代答需要合成键盘事件。
    /// promptIfNeeded = true 时未授权会弹系统引导
    static func accessibilityGranted(promptIfNeeded: Bool = false) -> Bool {
        // kAXTrustedCheckOptionPrompt 是 C 全局变量,Swift 6 判定非并发安全;键名是固定常量
        let options = ["AXTrustedCheckOptionPrompt": promptIfNeeded]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
