import AppKit

/// 统一退出入口。launchctl submit 托管的任务默认保活,直接 terminate 会被
/// launchd 立刻拉起——若当前进程正是该任务,必须先移除任务(随之终止本进程)。
@MainActor
enum AppQuit {
    static let launchdLabel = "dev.agentdock"

    static func quit() {
        if launchdJobPid() == getpid() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["remove", launchdLabel]
            try? process.run()
            // remove 会向本进程发 SIGTERM;万一没生效,兜底正常退出
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NSApp.terminate(nil)
            }
            return
        }
        NSApp.terminate(nil)
    }

    /// launchd 任务当前运行的 pid(任务不存在/未运行返回 nil)
    private static func launchdJobPid() -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", launchdLabel]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        // 输出形如:"PID" = 12345;
        guard let match = output.range(of: #""PID"\s*=\s*(\d+)"#, options: .regularExpression)
        else { return nil }
        let digits = output[match].filter(\.isNumber)
        return Int32(digits)
    }
}
