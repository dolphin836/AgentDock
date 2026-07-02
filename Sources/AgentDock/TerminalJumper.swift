import AppKit

/// 点击会话卡片 → 按 cwd 激活对应终端/编辑器窗口;都失败则复制路径。
@MainActor
enum TerminalJumper {
    static func jump(toCwd cwd: String) {
        guard !cwd.isEmpty else { return }
        let name = (cwd as NSString).lastPathComponent
        if activateITerm(matching: name) { return }
        if activateTerminal(matching: name) { return }
        if activateVSCode(matching: name) { return }
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

    private static func activateVSCode(matching name: String) -> Bool {
        runAppleScript("""
        tell application "System Events"
            if not (exists process "Code") then return false
            tell process "Code"
                repeat with w in windows
                    if name of w contains "\(name)" then
                        perform action "AXRaise" of w
                        set frontmost to true
                        return true
                    end if
                end repeat
            end tell
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
