import Foundation

/// Codex 限额主通道:读 ~/.codex/auth.json 的 OAuth token,直接调 ChatGPT 后端 usage 端点。
/// 免去每次刷新拉起 `codex app-server` 子进程;app-server 探针退为 fallback。
public enum CodexUsageProber {
    public static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    // MARK: 凭证

    public struct Credentials: Sendable, Equatable {
        public let accessToken: String
        public let accountId: String?
    }

    /// auth.json:{"tokens": {"access_token": "...", "account_id": "..."}}(兼容驼峰)
    static func parseAuthFile(_ data: Data) -> Credentials? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any]
        else { return nil }
        let token = (tokens["access_token"] ?? tokens["accessToken"]) as? String
        guard let token, !token.isEmpty else { return nil }
        let accountId = (tokens["account_id"] ?? tokens["accountId"]) as? String
        return Credentials(accessToken: token, accountId: accountId)
    }

    static func loadCredentials(home: String = NSHomeDirectory(),
                                env: [String: String] = ProcessInfo.processInfo.environment) -> Credentials? {
        let codexHome = env["CODEX_HOME"] ?? (home + "/.codex")
        guard let data = FileManager.default.contents(atPath: codexHome + "/auth.json") else { return nil }
        return parseAuthFile(data)
    }

    // MARK: 拉取

    public static func fetch(home: String = NSHomeDirectory()) async -> RateLimits? {
        guard let creds = loadCredentials(home: home) else { return nil }
        var request = URLRequest(url: usageURL)
        request.timeoutInterval = 15
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = creds.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return parseUsage(data)
    }

    /// 响应:{"rate_limit": {"primary_window": {"used_percent": 12, "reset_at": <epoch 秒>},
    ///                      "secondary_window": {...}}}
    static func parseUsage(_ data: Data, now: Date = Date()) -> RateLimits? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let rateLimit = root["rate_limit"] as? [String: Any]
        else { return nil }
        func window(_ key: String) -> (pct: Int?, resetAt: Date?) {
            guard let w = rateLimit[key] as? [String: Any] else { return (nil, nil) }
            let pct: Int?
            if let i = w["used_percent"] as? Int { pct = i }
            else if let d = w["used_percent"] as? Double { pct = Int(d.rounded()) }
            else { pct = nil }
            let resetAt = (w["reset_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            return (pct, resetAt)
        }
        let primary = window("primary_window")
        let secondary = window("secondary_window")
        guard primary.pct != nil || secondary.pct != nil else { return nil }
        return RateLimits(fiveHourPct: primary.pct, sevenDayPct: secondary.pct,
                          fiveHourResetAt: primary.resetAt, sevenDayResetAt: secondary.resetAt,
                          updatedAt: now)
    }
}
