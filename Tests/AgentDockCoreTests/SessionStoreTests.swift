import Testing
import Foundation
@testable import AgentDockCore

@MainActor
@Suite struct SessionStoreTests {
    private func hookEvent(_ name: String, session: String = "s1", at date: Date = Date()) -> IngestResult {
        .event(AgentEvent(sessionId: session, kind: .claudeCode,
                          cwd: "/Users/eric/proj", name: name, timestamp: date))
    }

    @Test func createsSessionAndTransitionsState() {
        let store = SessionStore()
        store.apply(hookEvent("SessionStart"))
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].state == .idle)
        #expect(store.sessions[0].projectName == "proj")

        store.apply(hookEvent("UserPromptSubmit"))
        #expect(store.sessions[0].state == .thinking)
        store.apply(hookEvent("PreToolUse"))
        #expect(store.sessions[0].state == .runningTool)
    }

    @Test func metricsAttachOnlyToExistingSession() {
        let store = SessionStore()
        store.apply(.metrics(sessionId: "ghost", kind: .claudeCode, Metrics(model: "Opus"), nil))
        #expect(store.sessions.isEmpty)

        store.apply(hookEvent("SessionStart"))
        store.apply(.metrics(sessionId: "s1", kind: .claudeCode, Metrics(model: "Opus", contextPct: 10),
                             RateLimits(fiveHourPct: 12, sevenDayPct: 34)))
        #expect(store.sessions[0].metrics?.model == "Opus")
        #expect(store.claudeRateLimits?.fiveHourPct == 12)
        #expect(store.claudeRateLimits?.sevenDayPct == 34)
    }

    @Test func codexTokenCountMetricsMergeAndSetCodexLimits() {
        let store = SessionStore()
        store.apply(.event(AgentEvent(sessionId: "t1", kind: .codex, cwd: "/x/p",
                                      name: "task_started")))
        // sqlite 回填带来的模型名
        store.apply(.metrics(sessionId: "t1", kind: .codex, Metrics(model: "gpt-5.5"), nil))
        // token_count 只带 ctx/tokens:按字段合并,模型名不能被抹掉
        store.apply(.metrics(sessionId: "t1", kind: .codex,
                             Metrics(contextPct: 9, totalTokens: 24057),
                             RateLimits(fiveHourPct: 1, sevenDayPct: 98)))
        #expect(store.sessions[0].metrics?.model == "gpt-5.5")
        #expect(store.sessions[0].metrics?.contextPct == 9)
        #expect(store.sessions[0].metrics?.totalTokens == 24057)
        #expect(store.codexRateLimits?.sevenDayPct == 98)
        #expect(store.claudeRateLimits == nil)  // codex 限额不能串到 claude
    }

    @Test func recentEventsCappedAt20() {
        let store = SessionStore()
        for _ in 0..<30 { store.apply(hookEvent("PreToolUse")) }
        #expect(store.sessions[0].recentEvents.count == 20)
    }

    @Test func pruneDisconnectsAndRemoves() {
        let store = SessionStore()
        let now = Date()
        store.apply(hookEvent("SessionStart", session: "old", at: now.addingTimeInterval(-3 * 3600)))
        store.apply(hookEvent("SessionStart", session: "stale", at: now.addingTimeInterval(-40 * 60)))
        store.apply(hookEvent("SessionStart", session: "fresh", at: now))
        store.prune(now: now)
        #expect(store.sessions.map(\.id).sorted() == ["fresh", "stale"])
        #expect(store.sessions.first(where: { $0.id == "stale" })?.state == .disconnected)
        #expect(store.sessions.first(where: { $0.id == "fresh" })?.state == .idle)
    }

    @Test func sortedByLastActivityDesc() {
        let store = SessionStore()
        let now = Date()
        store.apply(hookEvent("SessionStart", session: "a", at: now.addingTimeInterval(-60)))
        store.apply(hookEvent("SessionStart", session: "b", at: now))
        #expect(store.sessions.map(\.id) == ["b", "a"])
    }
}
