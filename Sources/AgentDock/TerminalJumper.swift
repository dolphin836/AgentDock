import AppKit
import AgentDockCore

extension AgentKind {
    /// 宿主未知时的兜底 App。Codex Desktop / Cursor 都能按项目找回历史会话;
    /// Claude 桌面端没有这个能力,不做兜底。
    var fallbackAppPath: String? {
        let path: String? = switch self {
        case .codex: "/Applications/Codex.app"
        case .cursor: "/Applications/Cursor.app"
        case .claudeCode: nil
        }
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }
}

/// 点击会话行 → 尽量直达会话现场:
/// 1. 终端类宿主(iTerm2/Terminal):AppleScript 按项目名选中具体窗口/tab/会话
/// 2. 编辑器类宿主(Cursor/VS Code/JetBrains...):携带项目路径打开 → 聚焦对应项目窗口
/// 3. 其他宿主:激活 App 主界面
/// 没有宿主信息时按 cwd 走终端匹配,再不行 Finder 定位(点击必须有可见反馈)。
@MainActor
enum TerminalJumper {

    /// 接受「打开目录 → 聚焦对应项目窗口」的编辑器(按 .app 名匹配)
    private static let editorApps: Set<String> = [
        "Cursor", "Visual Studio Code", "Code", "VSCodium", "Windsurf", "Zed",
        "PhpStorm", "IntelliJ IDEA", "GoLand", "WebStorm", "PyCharm",
        "RustRover", "CLion", "Sublime Text",
    ]

    static func jump(toCwd cwd: String, appPath: String? = nil, kind: AgentKind? = nil) {
        let appPath = appPath ?? kind?.fallbackAppPath
        let projectName = (cwd as NSString).lastPathComponent

        if let appPath, !appPath.isEmpty, FileManager.default.fileExists(atPath: appPath) {
            let appName = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension

            // 终端类:选中具体 tab/会话(需自动化授权,被拒时退化为激活 App)
            if appName == "iTerm" || appName == "iTerm2",
               PermissionGuide.mayUseAppleScript(bundleId: "com.googlecode.iterm2"),
               !projectName.isEmpty, activateITerm(matching: projectName) {
                return
            }
            if appName == "Terminal",
               PermissionGuide.mayUseAppleScript(bundleId: "com.apple.Terminal"),
               !projectName.isEmpty, activateTerminal(matching: projectName) {
                return
            }

            // 编辑器类:带上项目路径,聚焦(或恢复)该项目的窗口
            if editorApps.contains(appName), !cwd.isEmpty,
               FileManager.default.fileExists(atPath: cwd) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open([URL(fileURLWithPath: cwd, isDirectory: true)],
                                        withApplicationAt: URL(fileURLWithPath: appPath),
                                        configuration: config)
                return
            }

            // 其他宿主:激活主界面
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath),
                                               configuration: config)
            return
        }

        guard !cwd.isEmpty else { return }
        // 宿主未知:盲试终端匹配 → Finder 定位兜底
        if PermissionGuide.mayUseAppleScript(bundleId: "com.googlecode.iterm2"),
           activateITerm(matching: projectName) { return }
        if PermissionGuide.mayUseAppleScript(bundleId: "com.apple.Terminal"),
           activateTerminal(matching: projectName) { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cwd, forType: .string)
        if FileManager.default.fileExists(atPath: cwd) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: cwd)])
        }
    }

    /// iTerm2:逐层匹配 window → tab → session,全部选中(直达具体分栏)
    private static func activateITerm(matching name: String) -> Bool {
        runAppleScript("""
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if name of s contains "\(name)" then
                            select w
                            tell w to select t
                            tell t to select s
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

    /// Terminal:窗口名含项目名的置前;tab 级匹配(custom title 常为空)收益有限,不做
    private static func activateTerminal(matching name: String) -> Bool {
        runAppleScript("""
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if (custom title of t contains "\(name)") or (name of w contains "\(name)") then
                        set selected of t to true
                        set index of w to 1
                        activate
                        return true
                    end if
                end repeat
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
