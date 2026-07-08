import Testing
import Foundation
@testable import AgentDockCore

@Suite struct ClaudeUsageProberTests {
    @Test func parsesCredentialsFile() {
        let future = (Date().timeIntervalSince1970 + 3600) * 1000
        let json = Data("""
        {"claudeAiOauth": {"accessToken": "sk-ant-oat01-xyz", "refreshToken": "r",
         "expiresAt": \(future), "scopes": ["user:inference", "user:profile"]}}
        """.utf8)
        #expect(ClaudeUsageProber.parseCredentials(json) == "sk-ant-oat01-xyz")
    }

    @Test func rejectsExpiredCredentials() {
        let past = (Date().timeIntervalSince1970 - 3600) * 1000
        let json = Data("""
        {"claudeAiOauth": {"accessToken": "sk-ant-oat01-xyz", "expiresAt": \(past)}}
        """.utf8)
        #expect(ClaudeUsageProber.parseCredentials(json) == nil)
    }

    @Test func parsesUsageResponse() {
        let json = Data("""
        {"five_hour": {"utilization": 34.4, "resets_at": "2026-07-08T14:00:00.000Z"},
         "seven_day": {"utilization": 61.0, "resets_at": "2026-07-12T00:00:00Z"}}
        """.utf8)
        let limits = ClaudeUsageProber.parseUsage(json)
        #expect(limits?.fiveHourPct == 34)
        #expect(limits?.sevenDayPct == 61)
        #expect(limits?.fiveHourResetAt != nil)
        #expect(limits?.sevenDayResetAt != nil)
    }

    @Test func usageResponseWithoutWindowsIsNil() {
        #expect(ClaudeUsageProber.parseUsage(Data("{}".utf8)) == nil)
    }
}

@Suite struct CodexUsageProberTests {
    @Test func parsesAuthFile() {
        let json = Data("""
        {"OPENAI_API_KEY": null,
         "tokens": {"access_token": "eyJx", "refresh_token": "r", "account_id": "acc-1"},
         "last_refresh": "2026-07-01T00:00:00Z"}
        """.utf8)
        let creds = CodexUsageProber.parseAuthFile(json)
        #expect(creds?.accessToken == "eyJx")
        #expect(creds?.accountId == "acc-1")
    }

    @Test func parsesUsageResponse() {
        let json = Data("""
        {"plan_type": "plus",
         "rate_limit": {
           "primary_window": {"used_percent": 12, "reset_at": 1780000000, "limit_window_seconds": 18000},
           "secondary_window": {"used_percent": 91.6, "reset_at": 1780500000, "limit_window_seconds": 604800}}}
        """.utf8)
        let limits = CodexUsageProber.parseUsage(json)
        #expect(limits?.fiveHourPct == 12)
        #expect(limits?.sevenDayPct == 92)
        #expect(limits?.fiveHourResetAt == Date(timeIntervalSince1970: 1_780_000_000))
    }

    @Test func missingRateLimitIsNil() {
        #expect(CodexUsageProber.parseUsage(Data(#"{"plan_type":"plus"}"#.utf8)) == nil)
    }
}

@Suite struct CursorUsageProberTests {
    /// 构造只含 payload 的假 JWT(header.payload.signature)
    private func jwt(sub: String) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: ["sub": sub])
        let base64 = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJh.\(base64).sig"
    }

    @Test func extractsUserIdFromJWT() {
        #expect(CursorUsageProber.userId(fromJWT: jwt(sub: "auth0|user_01ABC")) == "user_01ABC")
        #expect(CursorUsageProber.userId(fromJWT: jwt(sub: "plain-id")) == "plain-id")
        #expect(CursorUsageProber.userId(fromJWT: "not-a-jwt") == nil)
        #expect(CursorUsageProber.userId(fromJWT: jwt(sub: "auth0|bad/id")) == nil)
    }

    @Test func parsesUsageSummary() {
        let json = Data("""
        {"billingCycleStart": "2026-06-15T00:00:00Z", "billingCycleEnd": "2026-07-15T00:00:00Z",
         "membershipType": "pro",
         "individualUsage": {
           "plan": {"enabled": true, "used": 1370, "limit": 2000,
                    "autoPercentUsed": 55.2, "apiPercentUsed": 81.7, "totalPercentUsed": 68.5},
           "onDemand": {"enabled": true, "used": 738, "limit": 10000}}}
        """.utf8)
        let usage = CursorUsageProber.parseUsage(json)
        #expect(usage?.planPct == 69)
        #expect(usage?.planUsedUSD == 13.70)
        #expect(usage?.planLimitUSD == 20.00)
        #expect(usage?.onDemandUsedUSD == 7.38)
        #expect(usage?.onDemandLimitUSD == 100.00)
        #expect(usage?.billingCycleEnd != nil)
    }

    @Test func derivesPercentFromSpendWhenMissing() {
        let json = Data("""
        {"individualUsage": {"plan": {"used": 500, "limit": 2000}}}
        """.utf8)
        #expect(CursorUsageProber.parseUsage(json)?.planPct == 25)
    }

    /// 企业/团队版:individualUsage 只有 overall,套餐指标在 teamUsage.pooled
    @Test func parsesTeamPooledShape() {
        let json = Data("""
        {"billingCycleEnd": "2026-08-01T00:00:00.000Z", "membershipType": "enterprise",
         "individualUsage": {"overall": {"enabled": false, "used": 125360, "limit": null}},
         "teamUsage": {
           "onDemand": {"enabled": true, "used": 0, "limit": 2000000},
           "pooled": {"enabled": true, "used": 1724050, "limit": 2640000}}}
        """.utf8)
        let usage = CursorUsageProber.parseUsage(json)
        #expect(usage?.planPct == 65)
        #expect(usage?.planUsedUSD == 17240.50)
        #expect(usage?.planLimitUSD == 26400.00)
        #expect(usage?.personalUsedUSD == 1253.60)
        #expect(usage?.onDemandUsedUSD == 0)
        #expect(usage?.onDemandLimitUSD == 20000.00)
    }

    @Test func unknownShapeIsNil() {
        #expect(CursorUsageProber.parseUsage(Data(#"{"foo":1}"#.utf8)) == nil)
    }
}

@Suite struct CodexProberGateTests {
    @Test func cooldownBlocksRelaunchAfterFailure() {
        CodexRateLimitProber.resetGate()
        defer { CodexRateLimitProber.resetGate() }

        let t0 = Date()
        #expect(CodexRateLimitProber.gateAllowsLaunch(now: t0))
        CodexRateLimitProber.recordOutcome(success: false, now: t0)
        #expect(!CodexRateLimitProber.gateAllowsLaunch(now: t0.addingTimeInterval(60)))
        #expect(CodexRateLimitProber.gateAllowsLaunch(
            now: t0.addingTimeInterval(CodexRateLimitProber.failureCooldown + 1)))

        CodexRateLimitProber.recordOutcome(success: true, now: t0)
        #expect(CodexRateLimitProber.gateAllowsLaunch(now: t0))
    }
}

@Suite struct RateLimitsMergeTests {
    @Test func mergePreservesResetTimesWhenIncomingLacksThem() {
        let oauth = RateLimits(fiveHourPct: 30, sevenDayPct: 60,
                               fiveHourResetAt: Date(timeIntervalSince1970: 1_780_000_000),
                               sevenDayResetAt: Date(timeIntervalSince1970: 1_780_500_000))
        let statusline = RateLimits(fiveHourPct: 35, sevenDayPct: 61)
        let merged = oauth.merging(statusline)
        #expect(merged.fiveHourPct == 35)
        #expect(merged.sevenDayPct == 61)
        #expect(merged.fiveHourResetAt == oauth.fiveHourResetAt)
        #expect(merged.sevenDayResetAt == oauth.sevenDayResetAt)
    }
}
