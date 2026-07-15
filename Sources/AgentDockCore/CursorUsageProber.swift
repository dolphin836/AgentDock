import Foundation
import SQLite3

/// Cursor 账号用量:从 Cursor.app 的 state.vscdb 取 OAuth token(cursorAuth/accessToken),
/// 解析 JWT 的 sub 得用户 id,合成 WorkosCursorSessionToken cookie 调官方 usage-summary。
/// 能拿到 hooks/transcript 完全没有的数据:套餐用量百分比、按需花费、账单周期。
public enum CursorUsageProber {
    public static let usageURL = URL(string: "https://cursor.com/api/usage-summary")!

    public struct ProbeResult: Sendable, Equatable {
        public var usage: CursorUsage?
        /// 失败原因(给用量页展示,不含 token)
        public var error: String?

        public init(usage: CursorUsage? = nil, error: String? = nil) {
            self.usage = usage
            self.error = error
        }
    }

    // MARK: 凭证(state.vscdb → JWT)

    static func accessToken(dbPath: String) -> String? {
        // Cursor 自己常占着写锁;只读也要多等一会,否则 busy 直接空
        for attempt in 0..<4 {
            if let token = readAccessTokenOnce(dbPath: dbPath) { return token }
            if attempt < 3 {
                Thread.sleep(forTimeInterval: 0.15 * Double(attempt + 1))
            }
        }
        return nil
    }

    private static func readAccessTokenOnce(dbPath: String) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 3_000)
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
        await probe(home: home).usage
    }

    public static func probe(home: String = NSHomeDirectory()) async -> ProbeResult {
        let dbPath = CursorStateReader.defaultDatabasePath(home: home)
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return ProbeResult(error: "no Cursor state.vscdb")
        }
        guard let cookie = cookieHeader(dbPath: dbPath) else {
            return ProbeResult(error: "not signed in to Cursor (no accessToken)")
        }
        var request = URLRequest(url: usageURL)
        request.timeoutInterval = 20
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AgentDock/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 200 else {
                return ProbeResult(error: "usage-summary HTTP \(code)")
            }
            guard let usage = parseUsage(data) else {
                return ProbeResult(error: "unrecognized usage-summary shape")
            }
            return ProbeResult(usage: usage)
        } catch {
            return ProbeResult(error: "network: \(error.localizedDescription)")
        }
    }

    /// 响应几种形状(金额多为「分」,JSON 里常是整数):
    /// - 个人版:individualUsage.plan {used, limit, totalPercentUsed} + individualUsage.onDemand
    /// - 企业/团队版(旧):teamUsage.pooled + individualUsage.overall + teamUsage.onDemand
    /// - 企业/团队版(新):仅 individualUsage.overall + teamUsage.onDemand(无 pooled/plan)
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
            guard let dict, let n = jsonNumber(dict[key]) else { return nil }
            return n / 100
        }
        var pct = jsonNumber(plan?["totalPercentUsed"]).map { Int($0.rounded()) }
        // 没有直接百分比时从花费/上限推导(团队池只有金额)
        if pct == nil, let used = cents(plan, "used"), let limit = cents(plan, "limit"), limit > 0 {
            pct = Int((used / limit * 100).rounded())
        }
        // 新企业形状无 pooled:用 overall 花费/上限凑套餐条(若有 limit)
        if pct == nil, let used = cents(overall, "used"), let limit = cents(overall, "limit"), limit > 0 {
            pct = Int((used / limit * 100).rounded())
        }
        let cycleEnd = (root["billingCycleEnd"] as? String).flatMap(ClaudeUsageProber.parseISO8601)
        let membership = root["membershipType"] as? String

        // 无 plan/pooled 时,把 overall 金额也映到 planUsed(方便 UI 显示主花费)
        let planUsed = cents(plan, "used") ?? (plan == nil ? cents(overall, "used") : nil)
        let planLimit = cents(plan, "limit") ?? (plan == nil ? cents(overall, "limit") : nil)

        let usage = CursorUsage(planPct: pct,
                                planUsedUSD: planUsed, planLimitUSD: planLimit,
                                onDemandUsedUSD: cents(onDemand, "used"),
                                onDemandLimitUSD: cents(onDemand, "limit"),
                                personalUsedUSD: cents(overall, "used"),
                                membershipType: membership,
                                billingCycleEnd: cycleEnd, updatedAt: now)
        // 全空说明响应形状不认识,不落一个空壳进 UI
        let hasData = usage.planPct != nil || usage.planUsedUSD != nil
            || usage.onDemandUsedUSD != nil || usage.personalUsedUSD != nil
        return hasData ? usage : nil
    }

    /// JSONSerialization 数字可能是 Int / Double / NSNumber,不能只 `as? Double`
    static func jsonNumber(_ value: Any?) -> Double? {
        if value == nil || value is NSNull { return nil }
        // NSNumber 优先:JSON 整数在 Apple 平台上就是它,as? Double 会失败
        if let n = value as? NSNumber {
            // Bool 也是 NSNumber,用量字段不应是 bool
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
            return n.doubleValue
        }
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let i as Int64: return Double(i)
        default: return nil
        }
    }
}
