import AppKit

/// 点击会话行 → 直接激活其宿主 App 主界面;没有宿主信息时按 cwd 回退到 AppleScript
/// 窗口匹配,再不行复制路径。
@MainActor
enum TerminalJumper {
    static func jump(toCwd cwd: String, appPath: String? = nil) {
        // 首选:精确激活宿主 App(发射脚本沿父进程链探测到的)
        if let appPath, !appPath.isEmpty, FileManager.default.fileExists(atPath: appPath) {
            let url = URL(fileURLWithPath: appPath)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
            return
        }
        guard !cwd.isEmpty else { return }
        let name = (cwd as NSString).lastPathComponent
        if activateITerm(matching: name) { return }
        if activateTerminal(matching: name) { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cwd, forType: .string)
    }

    private static func activateITerm(matching name: String) -> Bool {
        runAppleScript("""
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if name of s contains "\(name)" then
                            select w
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        return false
        """)
    }

    private static func activateTerminal(matching name: String) -> Bool {
        runAppleScript("""
        tell application "Terminal"
            repeat with w in windows
                if name of w contains "\(name)" then
                    set index of w to 1
                    activate
                    return true
                end if
            end repeat
        end tell
        return false
        """)
    }

    private static func runAppleScript(_ source: String) -> Bool {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if error != nil { return false }
        return result?.booleanValue == true
    }
}
