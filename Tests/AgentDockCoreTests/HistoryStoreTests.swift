import Testing
import Foundation
@testable import AgentDockCore

@Suite struct HistoryStoreTests {
    private func makeStore() -> HistoryStore {
        HistoryStore(path: NSTemporaryDirectory()
            + "agentdock-history-\(UUID().uuidString.prefix(8)).sqlite")
    }

    @Test func recordsSpansAndComputesStats() {
        let store = makeStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        // s1:思考 60s → 执行 120s → 等待输入 90s → 完成
        store.recordTransition(sessionId: "s1", kind: .codex, project: "p",
                               to: .thinking, at: base)
        store.recordTransition(sessionId: "s1", kind: .codex, project: "p",
                               to: .runningTool, at: base.addingTimeInterval(60))
        store.recordTransition(sessionId: "s1", kind: .codex, project: "p",
                               to: .waitingInput, at: base.addingTimeInterval(180))
        store.recordTransition(sessionId: "s1", kind: .codex, project: "p",
                               to: .done, at: base.addingTimeInterval(270))
        // token 采样:10k → 24k → 18k(compact 回落) → 20k;正增量 = 14k + 2k
        for (offset, tokens) in [(10.0, 10_000), (100.0, 24_000), (200.0, 18_000), (260.0, 20_000)] {
            store.recordTokens(sessionId: "s1", kind: .codex, tokens: tokens,
                               at: base.addingTimeInterval(offset))
        }
        store.flush()

        let stats = store.stats(since: base.addingTimeInterval(-10),
                                now: base.addingTimeInterval(300))
        #expect(Int(stats.activeSeconds) == 180)   // 60 思考 + 120 执行
        #expect(stats.waitCount == 1)
        #expect(Int(stats.avgWaitSeconds) == 90)
        #expect(stats.approxTokens == 16_000)

        // 窗口外无数据
        let empty = store.stats(since: base.addingTimeInterval(1000),
                                now: base.addingTimeInterval(2000))
        #expect(empty.activeSeconds == 0)
        #expect(empty.approxTokens == 0)
    }

    @Test func openSpanClippedToNowAndWaitCapped() {
        let store = makeStore()
        let base = Date(timeIntervalSince1970: 1_800_100_000)
        // 进行中的执行区间(未闭合):统计到 now 截止
        store.recordTransition(sessionId: "s2", kind: .cursor, project: "p",
                               to: .runningTool, at: base)
        // 挂了 2 小时的等待(未闭合):单次封顶 30 分钟
        store.recordTransition(sessionId: "s3", kind: .claudeCode, project: "q",
                               to: .waitingInput, at: base)
        store.flush()

        let stats = store.stats(since: base, now: base.addingTimeInterval(7200))
        #expect(Int(stats.activeSeconds) == 7200)
        #expect(stats.waitCount == 1)
        #expect(stats.avgWaitSeconds == HistoryStore.waitCapSeconds)
    }
}

@MainActor
@Suite struct SessionStoreObserverTests {
    @Test func diffNotifiesTransitionsAndTokens() {
        let store = SessionStore()
        var transitions: [(String, SessionState?)] = []
        var tokens: [(String, Int)] = []
        store.transitionObserver = { id, _, _, state in transitions.append((id, state)) }
        store.tokenObserver = { id, _, t in tokens.append((id, t)) }

        store.apply(.event(AgentEvent(sessionId: "a", kind: .codex, cwd: "/x/p",
                                      name: "task_started")))
        store.apply(.event(AgentEvent(sessionId: "a", kind: .codex, cwd: "/x/p",
                                      name: "function_call")))
        // 状态不变的事件不重复通知
        store.apply(.event(AgentEvent(sessionId: "a", kind: .codex, cwd: "/x/p",
                                      name: "function_call")))
        store.apply(.metrics(sessionId: "a", kind: .codex,
                             Metrics(totalTokens: 12_000), nil))
        // 移除 → newState = nil
        store.removeAfter = 0
        store.prune(now: Date().addingTimeInterval(3600))

        #expect(transitions.map(\.1) == [.thinking, .runningTool, nil])
        #expect(tokens.map(\.1) == [12_000])
    }
}
