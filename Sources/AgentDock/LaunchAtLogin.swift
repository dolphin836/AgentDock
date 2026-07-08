import Foundation

/// 开机自启:写入/移除 ~/Library/LaunchAgents 的 LaunchAgent。
/// 当前形态是裸二进制(未打包 .app),SMAppService 不适用,LaunchAgent 是正解;
/// 将来打包后可平滑换成 SMAppService.mainApp。
enum LaunchAtLogin {
    static let label = "dev.agentdock"
    static var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist"
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executable],
                "RunAtLoad": true,
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(
                atPath: (plistPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
        } else if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
    }
}
