import Testing
import Foundation
@testable import AgentDockCore

@Suite struct CodexRateLimitProberTests {
    @Test func parsesRateLimitsResponse() {
        let line = Data(#"{"jsonrpc":"2.0","id":2,"result":{"rateLimits":{"primary":{"usedPercent":4,"windowMinutes":300},"secondary":{"usedPercent":9,"windowMinutes":10080}},"planType":"pro"}}"#.utf8)
        let limits = CodexRateLimitProber.parseResponse(line)
        #expect(limits?.fiveHourPct == 4)
        #expect(limits?.sevenDayPct == 9)
    }

    @Test func ignoresOtherMessages() {
        #expect(CodexRateLimitProber.parseResponse(Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)) == nil)
        #expect(CodexRateLimitProber.parseResponse(Data("garbage".utf8)) == nil)
    }
}
