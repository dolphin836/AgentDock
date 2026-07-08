import Foundation
import Security

/// Claude 限额主通道:用 Claude Code 的 OAuth 凭证直接调官方 usage 端点。
/// 比 statusline 旁路更稳(不依赖任务在跑)且带窗口重置时间。
/// 凭证来源:~/.claude/.credentials.json → macOS 钥匙串「Claude Code-credentials」。
public enum ClaudeUsageProber {
    public static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let keychainService = "Claude Code-credentials"

    /// 钥匙串读取失败后的冷却(首次会弹系统授权框,拒绝后不应反复骚扰)
    private static let keychainCooldown: TimeInterval = 1800
    /// 端点 429 后的冷却:优先遵守响应的 Retry-After,缺失时用默认值
    private static let defaultRateLimitCooldown: TimeInterval = 900
    private static let lock = NSLock()
    private nonisolated(unsafe) static var keychainFailedAt: Date?
    private nonisolated(unsafe) static var rateLimitBlockedUntil: Date?

    // MARK: 凭证

    /// 凭证 JSON:{"claudeAiOauth": {"accessToken": "...", "expiresAt": <ms>}}
    static func parseCredentials(_ data: Data, now: Date = Date()) -> String? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }
        if let expiresMs = oauth["expiresAt"] as? Double,
           now.timeIntervalSince1970 * 1000 >= expiresMs {
            return nil  // 已过期:刷新流程归 Claude Code 自己,这里不代劳
        }
        return token
    }

    static func loadAccessToken(home: String = NSHomeDirectory()) -> String? {
        if let data = FileManager.default.contents(atPath: home + "/.claude/.credentials.json"),
           let token = parseCredentials(data) {
            return token
        }
        return keychainAccessToken()
    }

    private static func keychainAccessToken() -> String? {
        lock.lock()
        if let failedAt = keychainFailedAt, Date().timeIntervalSince(failedAt) < keychainCooldown {
            lock.unlock()
            return nil
        }
        lock.unlock()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let token = parseCredentials(data) else {
            lock.lock()
            keychainFailedAt = Date()
            lock.unlock()
            return nil
        }
        lock.lock()
        keychainFailedAt = nil
        lock.unlock()
        return token
    }

    // MARK: 拉取

    private static func isRateLimited() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let until = rateLimitBlockedUntil else { return false }
        return Date() < until
    }

    private static func markRateLimited(retryAfter: TimeInterval?) {
        lock.lock()
        defer { lock.unlock() }
        rateLimitBlockedUntil = Date().addingTimeInterval(retryAfter ?? defaultRateLimitCooldown)
    }

    public static func fetch(home: String = NSHomeDirectory()) async -> RateLimits? {
        guard !isRateLimited() else { return nil }
        guard let token = loadAccessToken(home: home) else { return nil }
        var request = URLRequest(url: usageURL)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            markRateLimited(retryAfter: retryAfter)
            return nil
        }
        guard http.statusCode == 200 else { return nil }
        return parseUsage(data)
    }

    /// 响应:{"five_hour": {"utilization": 34.2, "resets_at": ISO8601}, "seven_day": {...}}
    static func parseUsage(_ data: Data, now: Date = Date()) -> RateLimits? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        func window(_ key: String) -> (pct: Int?, resetAt: Date?) {
            guard let w = root[key] as? [String: Any] else { return (nil, nil) }
            let pct = (w["utilization"] as? Double).map { Int($0.rounded()) }
            let resetAt = (w["resets_at"] as? String).flatMap(parseISO8601)
            return (pct, resetAt)
        }
        let fiveHour = window("five_hour")
        let sevenDay = window("seven_day")
        guard fiveHour.pct != nil || sevenDay.pct != nil else { return nil }
        return RateLimits(fiveHourPct: fiveHour.pct, sevenDayPct: sevenDay.pct,
                          fiveHourResetAt: fiveHour.resetAt, sevenDayResetAt: sevenDay.resetAt,
                          updatedAt: now)
    }

    static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
