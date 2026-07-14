import Testing
import Foundation
@testable import AgentDockCore

@Suite struct UpdateCheckerTests {
    @Test func newerVersionDetected() {
        #expect(UpdateChecker.isNewer("0.2.0", than: "0.1.0"))
        #expect(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
        #expect(UpdateChecker.isNewer("0.1.1", than: "0.1.0"))
        #expect(UpdateChecker.isNewer("10.0.0", than: "9.0.0"))
    }

    @Test func sameOrOlderVersionNotDetected() {
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.1.0"))
        #expect(!UpdateChecker.isNewer("0.0.9", than: "0.1.0"))
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.2.0"))
    }

    @Test func toleratesPrefixAndUnevenComponents() {
        #expect(UpdateChecker.isNewer("v0.2.0", than: "v0.1.0"))
        #expect(UpdateChecker.isNewer("0.2", than: "0.1.9"))
        #expect(!UpdateChecker.isNewer("1.2", than: "1.2.0"))
        #expect(UpdateChecker.isNewer("1.2.1", than: "1.2"))
        #expect(UpdateChecker.isNewer(" 0.2.0\n", than: "0.1.0"))
    }

    @Test func decodesFeedJSON() throws {
        let json = Data("""
        {"version": "0.2.3", "download": "https://api.agentdockstatus.app/v1/download/AgentDock-0.2.3.pkg"}
        """.utf8)
        let info = try JSONDecoder().decode(UpdateInfo.self, from: json)
        #expect(info.version == "0.2.3")
        #expect(info.download == "https://api.agentdockstatus.app/v1/download/AgentDock-0.2.3.pkg")
    }
}
