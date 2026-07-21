import Testing
import Foundation
@testable import AgentDockCore

@Suite struct SubagentDisplayTests {
    @Test func runningCountParsesLeadingIntegerFromDetail() {
        #expect(SubagentDisplay.runningCount(detail: SubagentDisplay.progressDetail(count: 3)) == 3)
        #expect(SubagentDisplay.runningCount(detail: "2 个子任务运行中") == 2)
        #expect(SubagentDisplay.runningCount(detail: "12 running subtasks") == 12)
    }

    @Test func runningCountFallsBackToOneOnUnparseableOrZero() {
        // 运行中至少一个:解析不出或为 0 都回退 1,避免「运行中却显示 0」。
        #expect(SubagentDisplay.runningCount(detail: nil) == 1)
        #expect(SubagentDisplay.runningCount(detail: "Task") == 1)
        #expect(SubagentDisplay.runningCount(detail: "0 个子任务运行中") == 1)
    }

    @Test func runningLabelIsLocalized() {
        #expect(SubagentDisplay.runningLabel(count: 2, chinese: true) == "子任务中… · 2个运行中")
        #expect(SubagentDisplay.runningLabel(count: 1, chinese: false) == "Subtasks… · 1 running")
    }

    @Test func eventClassificationSeparatesProgressFromComplete() {
        #expect(SubagentDisplay.isProgressEvent("subagentProgress"))
        #expect(!SubagentDisplay.isProgressEvent("subagentComplete"))
        #expect(SubagentDisplay.isCompleteEvent("subagentComplete"))
        #expect(!SubagentDisplay.isCompleteEvent("subagentProgress"))
        // 普通工具事件都不属于子任务聚合事件。
        #expect(!SubagentDisplay.isProgressEvent("preToolUse"))
        #expect(!SubagentDisplay.isCompleteEvent("postToolUse"))
    }

    @MainActor
    @Test func menuStillCountsParentOnceForAggregatedSubagents() {
        // 子 agent 不作为独立会话展示:多次 subagentProgress 只让父会话计一次运行中。
        let store = SessionStore()
        store.apply(.event(AgentEvent(
            sessionId: "P", kind: .cursor, cwd: "/x/p", name: "subagentProgress",
            detail: SubagentDisplay.progressDetail(count: 2), tool: "Task")))
        store.apply(.event(AgentEvent(
            sessionId: "P", kind: .cursor, cwd: "/x/p", name: "subagentProgress",
            detail: SubagentDisplay.progressDetail(count: 1), tool: "Task")))
        let running = store.sessions.filter { $0.state == .thinking || $0.state == .runningTool }
        #expect(running.count == 1)
        #expect(running.first?.id == "P")

        // 完成事件把父会话带回 thinking,不新增会话、不污染为运行工具。
        store.apply(.event(AgentEvent(
            sessionId: "P", kind: .cursor, cwd: "/x/p", name: "subagentComplete",
            detail: "Task", tool: "Task")))
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.state == .thinking)
    }
}
