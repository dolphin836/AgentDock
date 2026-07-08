import Foundation
import SQLite3

/// Cursor 账号用量:从 Cursor.app 的 state.vscdb 取 OAuth token(cursorAuth/accessToken),
/// 解析 JWT 的 sub 得用户 id,合成 WorkosCursorSessionToken cookie 调官方 usage-summary。
/// 能拿到 hooks/transcript 完全没有的数据:套餐用量百分比、按需花费、账单周期。
public enum CursorUsageProber {
    public static let usageURL = URL(string: "https://cursor.com/api/usage-summary")!

    // MARK: 凭证(state.vscdb → JWT)

    static func accessToken(dbPath: String) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)
        var stmt: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW, let text = sqlite3_column_text(stmt, 0) else { return nil }
        let token = String(cString: text).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return token.isEmpty ? nil : token
    }

    /// JWT payload 的 sub(如 "auth0|user_xxx")→ 取 "|" 后段作为用户 id
    static func userId(fromJWT token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let sub = json["sub"] as? String,
              let id = sub.split(separator: "|", omittingEmptySubsequences: true).last.map(String.init),
              !id.isEmpty
        else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard id.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return id
    }

    static func cookieHeader(dbPath: String) -> String? {
        guard let token = accessToken(dbPath: dbPath),
              let user = userId(fromJWT: token) else { return nil }
        return "WorkosCursorSessionToken=\(user)%3A%3A\(token)"
    }

    // MARK: 拉取

    public static func fetch(home: String = NSHomeDirectory()) async -> CursorUsage? {
        let dbPath = CursorStateReader.defaultDatabasePath(home: home)
        guard let cookie = cookieHeader(dbPath: dbPath) else { return nil }
        var request = URLRequest(url: usageURL)
        request.timeoutInterval = 15
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return parseUsage(data)
    }

    /// 响应两种形状(金额均为「分」):
    /// - 个人版:individualUsage.plan {used, limit, totalPercentUsed} + individualUsage.onDemand
    /// - 企业/团队版:teamUsage.pooled {used, limit}(共享池,作套餐主指标)
    ///   + individualUsage.overall.used(本人花费) + teamUsage.onDemand
    static func parseUsage(_ data: Data, now: Date = Date()) -> CursorUsage? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        let individual = root["individualUsage"] as? [String: Any]
        let team = root["teamUsage"] as? [String: Any]
        let plan = (individual?["plan"] as? [String: Any])
            ?? (team?["pooled"] as? [String: Any])
        let onDemand = (individual?["onDemand"] as? [String: Any])
            ?? (team?["onDemand"] as? [String: Any])
        let overall = individual?["overall"] as? [String: Any]

        func cents(_ dict: [String: Any]?, _ key: String) -> Double? {
            guard let dict else { return nil }
            if let d = dict[key] as? Double { return d / 100 }
            return nil
        }
        var pct = (plan?["totalPercentUsed"] as? Double).map { Int($0.rounded()) }
        // 没有直接百分比时从花费/上限推导(团队池只有金额)
        if pct == nil, let used = cents(plan, "used"), let limit = cents(plan, "limit"), limit > 0 {
            pct = Int((used / limit * 100).rounded())
        }
        let cycleEnd = (root["billingCycleEnd"] as? String).flatMap(ClaudeUsageProber.parseISO8601)

        let usage = CursorUsage(planPct: pct,
                                planUsedUSD: cents(plan, "used"), planLimitUSD: cents(plan, "limit"),
                                onDemandUsedUSD: cents(onDemand, "used"),
                                onDemandLimitUSD: cents(onDemand, "limit"),
                                personalUsedUSD: cents(overall, "used"),
                                billingCycleEnd: cycleEnd, updatedAt: now)
        // 全空说明响应形状不认识,不落一个空壳进 UI
        let hasData = usage.planPct != nil || usage.planUsedUSD != nil
            || usage.onDemandUsedUSD != nil || usage.personalUsedUSD != nil
        return hasData ? usage : nil
    }
}
