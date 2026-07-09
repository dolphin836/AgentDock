import AppKit
import Carbon.HIToolbox
import AgentDockCore

/// Codex/Cursor 的辅助代答:两家都没有外部应答接口(Claude 走 hook 阻塞是真代答),
/// 只能聚焦宿主 App 后代按它们各自的审批快捷键。需要「辅助功能」授权。
@MainActor
enum AssistedApproval {

    /// 该会话是否支持辅助代答
    static func supports(_ kind: AgentKind) -> Bool {
        kind == .codex || kind == .cursor
    }

    static func respond(session: AgentSession, allow: Bool) {
        // 只静默检查,绝不在每次允许/拒绝时弹系统授权框(会反复打扰)。
        // 未授权时仍聚焦宿主窗口;按键需要用户在设置页或系统设置里打开辅助功能。
        let trusted = PermissionGuide.accessibilityGranted()
        // 必须聚焦到该会话所在的项目窗口,不能只激活 App:
        // 多窗口时按键会打进错误的窗口,看起来就是「点了没反应」
        TerminalJumper.jump(toCwd: session.cwd, appPath: session.appPath, kind: session.kind)
        guard trusted else { return }
        // 等待目标窗口拿到焦点再按键(窗口切换比 App 激活慢)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sendKeys(kind: session.kind, allow: allow)
        }
    }

    private static func sendKeys(kind: AgentKind, allow: Bool) {
        switch kind {
        case .codex:
            // Codex TUI 审批弹窗:y = 批准,n = 拒绝
            post(key: allow ? kVK_ANSI_Y : kVK_ANSI_N)
        case .cursor:
            // Cursor 审批卡片:⌘⏎ = 批准执行,⌘⌫ = 拒绝
            post(key: allow ? kVK_Return : kVK_Delete, flags: .maskCommand)
        case .claudeCode:
            break  // Claude 走 hook 阻塞代答,不需要按键
        }
    }

    private static func post(key: Int, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source,
                                      virtualKey: CGKeyCode(key), keyDown: down) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
