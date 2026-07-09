import Foundation

/// 匿名遥测:下载计数在 API 边缘完成;本模块只上报启动活跃与崩溃。
/// 不采集会话内容 / 路径 / token / 邮箱等敏感字段。
public enum Telemetry {
    public static let apiBase = URL(string: "https://api.agentdockstatus.app")!

    private static let installIdKey = "AgentDockInstallID"
    private static let lastLaunchDayKey = "AgentDockLastLaunchDay"
    private static let state = State()

    public static var installID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: installIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        defaults.set(id, forKey: installIdKey)
        return id
    }

    /// App 启动时调用:每天最多记一次 launch(活跃安装),同日重复启动静默跳过。
    public static func recordLaunch(appVersion: String) {
        guard state.markLaunchSent() else { return }

        let day = dayStamp()
        let defaults = UserDefaults.standard
        if defaults.string(forKey: lastLaunchDayKey) == day { return }
        defaults.set(day, forKey: lastLaunchDayKey)

        post(path: "/v1/event", body: basePayload(appVersion: appVersion, extra: ["event": "launch"]))
    }

    public static func installCrashReporting(appVersion: String) {
        guard state.markCrashHandlerInstalled(appVersion: appVersion) else { return }
        // NSSetUncaughtExceptionHandler 需要 C 函数指针,不能用捕获闭包
        NSSetUncaughtExceptionHandler(agentDockUncaughtExceptionHandler)
        flushPendingCrash(appVersion: appVersion)
    }

    public static func reportCrash(
        appVersion: String,
        name: String?,
        reason: String?,
        stack: String?
    ) {
        var payload = basePayload(appVersion: appVersion, extra: [:])
        payload["name"] = name ?? "unknown"
        payload["reason"] = reason ?? ""
        payload["stack"] = String((stack ?? "").prefix(8000))

        // 先落盘,进程马上要挂时网络可能发不出去
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: pendingCrashURL(), options: .atomic)
        }
        post(path: "/v1/crash", body: payload)
    }

    // MARK: - Internals

    fileprivate static func cachedAppVersion() -> String {
        state.appVersion
    }

    private static func basePayload(appVersion: String, extra: [String: Any]) -> [String: Any] {
        var body: [String: Any] = [
            "install_id": installID,
            "app_version": appVersion,
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "arch": currentArch(),
        ]
        for (k, v) in extra { body[k] = v }
        return body
    }

    private static func currentArch() -> String {
#if arch(arm64)
        return "arm64"
#elseif arch(x86_64)
        return "x86_64"
#else
        return "unknown"
#endif
    }

    private static func dayStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func pendingCrashURL() -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentdock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pending-crash.json")
    }

    private static func flushPendingCrash(appVersion: String) {
        let url = pendingCrashURL()
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        var body = obj
        body["app_version"] = body["app_version"] ?? appVersion
        post(path: "/v1/crash", body: body) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func post(
        path: String,
        body: [String: Any],
        onSuccess: (@Sendable () -> Void)? = nil
    ) {
        guard let url = URL(string: path, relativeTo: apiBase) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task.detached(priority: .utility) {
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else { return }
            onSuccess?()
        }
    }

    /// 崩溃 handler 可能在任意线程触发,用锁保护进程内状态。
    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var didSendLaunch = false
        private var crashHandlerInstalled = false
        private var _appVersion = "0.0.0"

        var appVersion: String {
            lock.lock(); defer { lock.unlock() }
            return _appVersion
        }

        func markLaunchSent() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if didSendLaunch { return false }
            didSendLaunch = true
            return true
        }

        func markCrashHandlerInstalled(appVersion: String) -> Bool {
            lock.lock(); defer { lock.unlock() }
            _appVersion = appVersion
            if crashHandlerInstalled { return false }
            crashHandlerInstalled = true
            return true
        }
    }
}

/// C 约定入口:ObjC 未捕获异常 → 落盘 + 尝试上报
private func agentDockUncaughtExceptionHandler(_ exception: NSException) {
    Telemetry.reportCrash(
        appVersion: Telemetry.cachedAppVersion(),
        name: exception.name.rawValue,
        reason: exception.reason,
        stack: exception.callStackSymbols.joined(separator: "\n")
    )
}
