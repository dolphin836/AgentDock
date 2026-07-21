import Testing
import Foundation
@testable import AgentDockCore

@MainActor
@Suite struct CursorSubagentAggregatorTests {
    private func userLine() -> Data {
        Data(#"{"role":"user","message":{"content":[{"type":"text","text":"go"}]}}"#.utf8)
    }
    private func toolLine() -> Data {
        Data(#"{"role":"assistant","message":{"content":[{"type":"tool_use","name":"Shell"}]}}"#.utf8)
    }
    private func stopLine() -> Data {
        Data(#"{"type":"turn_ended","status":"success"}"#.utf8)
    }

    @Test func nonTerminalChildEmitsParentProgress() {
        let agg = CursorSubagentAggregator()
        let result = agg.ingest(parentId: "P", childId: "c1", cwd: "/x/p", line: toolLine())
        guard case .event(let e) = result else { Issue.record("expected event"); return }
        #expect(e.sessionId == "P")
        #expect(e.kind == .cursor)
        #expect(e.name == "subagentProgress")
        #expect(e.tool == "Task")
        #expect(e.cwd == "/x/p")
        // detail 展示运行中子任务数
        #expect(e.detail?.contains("1") == true)
    }

    @Test func progressMapsToRunningToolViaEventMapping() {
        let agg = CursorSubagentAggregator()
        guard case .event(let e) = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine())
        else { Issue.record("expected event"); return }
        #expect(mapEventToState(e, current: .thinking) == .runningTool)
    }

    @Test func multipleChildrenOneStopStillRunning() {
        let agg = CursorSubagentAggregator()
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine())
        _ = agg.ingest(parentId: "P", childId: "c2", cwd: nil, line: userLine())
        // c1 结束,c2 仍在跑 → 依然是进度事件,detail 计数为 1
        let result = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: stopLine())
        guard case .event(let e) = result else { Issue.record("expected event"); return }
        #expect(e.name == "subagentProgress")
        #expect(e.detail?.contains("1") == true)
    }

    @Test func lastChildStopEmitsDedicatedCompletion() {
        let agg = CursorSubagentAggregator()
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine())
        _ = agg.ingest(parentId: "P", childId: "c2", cwd: nil, line: userLine())
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: stopLine())
        // 最后一个子任务结束 → 父会话回到 thinking,但不伪造通用 tool end
        let result = agg.ingest(parentId: "P", childId: "c2", cwd: nil, line: stopLine())
        guard case .event(let e) = result else { Issue.record("expected event"); return }
        #expect(e.sessionId == "P")
        #expect(e.name == "subagentComplete")
        #expect(mapEventToState(e, current: .runningTool) == .thinking)
    }

    @Test func parentTerminalIsDeferredUntilLastChildStops() {
        let agg = CursorSubagentAggregator()
        let store = SessionStore()
        store.apply(.event(AgentEvent(
            sessionId: "P", kind: .cursor, cwd: "/x/p", name: "beforeSubmitPrompt")))
        store.apply(agg.ingest(parentId: "P", childId: "c1", cwd: "/x/p", line: userLine()))

        #expect(agg.hasActiveChildren(parentId: "P"))
        #expect(store.sessions.first(where: { $0.id == "P" })?.state == .runningTool)
        // 父 transcript 先落 turn_ended：AppDelegate 应延迟，不立即 apply done。
        agg.deferParentTerminal(parentId: "P", eventName: "stop")
        #expect(store.sessions.first(where: { $0.id == "P" })?.state == .runningTool)

        let final = agg.ingest(parentId: "P", childId: "c1", cwd: "/x/p", line: stopLine())
        guard case .event(let event) = final else { Issue.record("expected event"); return }
        #expect(event.name == "stop")
        store.apply(final)
        #expect(store.sessions.first(where: { $0.id == "P" })?.state == .done)
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func parentTerminalWithoutChildrenNeedsNoDeferral() {
        let agg = CursorSubagentAggregator()
        #expect(!agg.hasActiveChildren(parentId: "P"))
        let stop = AgentEvent(sessionId: "P", kind: .cursor, name: "stop")
        #expect(mapEventToState(stop, current: .thinking) == .done)
    }

    @Test func unknownChildTerminalFirstIsIgnored() {
        let agg = CursorSubagentAggregator()
        let result = agg.ingest(
            parentId: "P", childId: "unknown", cwd: nil, line: stopLine())
        #expect(result == .ignored)
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func hookChildrenAggregateUntilLastStop() {
        let agg = CursorSubagentAggregator()
        _ = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStart", cwd: "/x/p")
        _ = agg.ingestHook(
            parentId: "P", childId: "c2", eventName: "subagentStart", cwd: "/x/p")

        let oneStopped = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStop", cwd: "/x/p")
        guard case .event(let progress) = oneStopped else {
            Issue.record("expected progress"); return
        }
        #expect(progress.name == "subagentProgress")
        #expect(progress.detail?.contains("1") == true)

        let final = agg.ingestHook(
            parentId: "P", childId: "c2", eventName: "subagentStop", cwd: "/x/p")
        guard case .event(let complete) = final else {
            Issue.record("expected completion"); return
        }
        #expect(complete.name == "subagentComplete")
    }

    @Test func hookStopReleasesDeferredParentTerminal() {
        let agg = CursorSubagentAggregator()
        _ = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStart", cwd: nil)
        _ = agg.ingestHook(
            parentId: "P", childId: "c2", eventName: "subagentStart", cwd: nil)
        agg.deferParentTerminal(parentId: "P", eventName: "sessionEnd")
        _ = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStop", cwd: nil)
        let final = agg.ingestHook(
            parentId: "P", childId: "c2", eventName: "subagentStop", cwd: nil)
        guard case .event(let event) = final else {
            Issue.record("expected terminal"); return
        }
        #expect(event.name == "sessionEnd")
    }

    @Test func mixedHookAndTranscriptSignalsDoNotDuplicateChild() {
        let agg = CursorSubagentAggregator()
        _ = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStart", cwd: nil)
        // 同一 child 的 transcript 进度只刷新状态，不增加计数。
        let progress = agg.ingest(
            parentId: "P", childId: "c1", cwd: nil, line: userLine())
        guard case .event(let event) = progress else {
            Issue.record("expected progress"); return
        }
        #expect(event.detail?.contains("1") == true)

        let final = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStop", cwd: nil)
        guard case .event(let complete) = final else {
            Issue.record("expected completion"); return
        }
        #expect(complete.name == "subagentComplete")
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func resetAndPruneClearStaleParentState() {
        let agg = CursorSubagentAggregator()
        let t0 = Date()
        _ = agg.ingestHook(
            parentId: "P", childId: "c1", eventName: "subagentStart",
            cwd: nil, at: t0)
        agg.prune(now: t0.addingTimeInterval(2 * 60 * 60 + 1))
        #expect(!agg.hasActiveChildren(parentId: "P"))

        _ = agg.ingestHook(
            parentId: "P", childId: "c2", eventName: "subagentStart", cwd: nil)
        agg.reset(parentId: "P")
        #expect(!agg.hasActiveChildren(parentId: "P"))
        #expect(agg.ingestHook(
            parentId: "P", childId: "c2", eventName: "subagentStop", cwd: nil) == .ignored)
    }

    @Test func parentsAreIsolated() {
        let agg = CursorSubagentAggregator()
        _ = agg.ingest(parentId: "P1", childId: "c1", cwd: nil, line: userLine())
        _ = agg.ingest(parentId: "P2", childId: "c1", cwd: nil, line: userLine())
        // P1 的子任务全部结束不影响 P2
        let result = agg.ingest(parentId: "P1", childId: "c1", cwd: nil, line: stopLine())
        guard case .event(let e) = result else { Issue.record("expected event"); return }
        #expect(e.name == "subagentComplete")
        // P2 仍在跑
        let p2 = agg.ingest(parentId: "P2", childId: "c2", cwd: nil, line: userLine())
        guard case .event(let e2) = p2 else { Issue.record("expected event"); return }
        #expect(e2.name == "subagentProgress")
        #expect(e2.detail?.contains("2") == true)
    }

    @Test func malformedLineIsIgnored() {
        let agg = CursorSubagentAggregator()
        let result = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: Data("not json".utf8))
        #expect(result == .ignored)
    }

    // MARK: I1 身份别名与幻影子任务

    @Test func startWithExplicitAndPathAliasesResolvesStopByEitherAlias() {
        // subagentStart 记录 subagent_id(tool_call_id)与 transcript path stem 两个别名到同一 canonical child。
        let agg = CursorSubagentAggregator()
        _ = agg.ingestHook(
            parentId: "P", childId: "tool_1", eventName: "subagentStart",
            cwd: "/x/p", aliases: ["child-uuid-1"])
        #expect(agg.hasActiveChildren(parentId: "P"))
        // stop 只带 transcript path stem 别名 → 仍解析到同一 child 并完成。
        let final = agg.ingestHook(
            parentId: "P", childId: "child-uuid-1", eventName: "subagentStop", cwd: "/x/p")
        guard case .event(let e) = final else { Issue.record("expected completion"); return }
        #expect(e.name == "subagentComplete")
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func hookStartTranscriptProgressStopShareOneCanonicalChildAcrossIds() {
        // 幻影子任务:hook 用 tool_call_id、transcript tailer 用 conversation uuid，不得算成两个。
        let agg = CursorSubagentAggregator()
        _ = agg.ingestHook(
            parentId: "P", childId: "tool_1", eventName: "subagentStart",
            cwd: nil, aliases: ["child-uuid-1"])
        // transcript 用 conversation uuid 报进度 → 命中别名，计数仍为 1。
        guard case .event(let progress) = agg.ingest(
            parentId: "P", childId: "child-uuid-1", cwd: nil, line: userLine())
        else { Issue.record("expected progress"); return }
        #expect(progress.detail?.contains("1") == true)
        // stop 用 tool_call_id → 命中同一 child，唯一完成。
        let final = agg.ingestHook(
            parentId: "P", childId: "tool_1", eventName: "subagentStop", cwd: nil)
        guard case .event(let complete) = final else { Issue.record("expected completion"); return }
        #expect(complete.name == "subagentComplete")
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func anonymousStopReleasesOldestActiveChildFIFO() {
        // stop 既无 path 也无 subagent_id，但 parent 可知:FIFO 释放最老的一个,绝不永久挂起。
        let agg = CursorSubagentAggregator()
        let t0 = Date()
        _ = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStart",
                           cwd: nil, at: t0)
        _ = agg.ingestHook(parentId: "P", childId: "c2", eventName: "subagentStart",
                           cwd: nil, at: t0.addingTimeInterval(1))
        // 匿名 stop:childId 空、无别名。
        guard case .event(let e) = agg.ingestHook(
            parentId: "P", childId: "", eventName: "subagentStop",
            cwd: nil, at: t0.addingTimeInterval(2))
        else { Issue.record("expected progress"); return }
        #expect(e.name == "subagentProgress")
        #expect(e.detail?.contains("1") == true)
    }

    @Test func anonymousStopWithUnknownParentIsIgnored() {
        // 连 parent 都未知(无活跃集合)→ 忽略,依赖 TTL。
        let agg = CursorSubagentAggregator()
        let result = agg.ingestHook(
            parentId: "P", childId: "", eventName: "subagentStop", cwd: nil)
        #expect(result == .ignored)
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func identifiedButUnmatchedStopIsIgnoredNotFIFO() {
        // stop 带了明确 child id,只是不匹配(tailer 启动边界/旧文件):忽略,不得 FIFO 误伤在跑子任务。
        let agg = CursorSubagentAggregator()
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine())
        let result = agg.ingestHook(
            parentId: "P", childId: "stranger", eventName: "subagentStop", cwd: nil)
        #expect(result == .ignored)
        #expect(agg.hasActiveChildren(parentId: "P"))
    }

    @Test func staleHookChildIsReconciledBeforeParentHangs() {
        // subagent transcript 常无终态(0 个 turn_ended),hook 也可能丢 stop:
        // 短于 2h 的 stale 超时必须回收,让父会话不永久卡 running。
        let agg = CursorSubagentAggregator(childStaleTimeout: 30 * 60, transcriptStopDebounce: 5)
        let t0 = Date()
        _ = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStart",
                           cwd: nil, at: t0)
        #expect(agg.hasActiveChildren(parentId: "P"))
        let events = agg.prune(now: t0.addingTimeInterval(30 * 60 + 1))
        #expect(!agg.hasActiveChildren(parentId: "P"))
        // 最后一个 child 被回收 → 发出专用完成态,父会话回 thinking。
        #expect(events.contains { if case .event(let e) = $0 { return e.name == "subagentComplete" && e.sessionId == "P" }; return false })
    }

    @Test func staleReconciliationReleasesDeferredParentTerminal() {
        // 父 terminal 已 defer,子任务变 stale:prune 必须放出被暂存的父终态,不让父永久 defer。
        let agg = CursorSubagentAggregator(childStaleTimeout: 30 * 60, transcriptStopDebounce: 5)
        let t0 = Date()
        _ = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStart",
                           cwd: nil, at: t0)
        agg.deferParentTerminal(parentId: "P", eventName: "sessionEnd", at: t0)
        let events = agg.prune(now: t0.addingTimeInterval(30 * 60 + 1))
        #expect(events.contains { if case .event(let e) = $0 { return e.name == "sessionEnd" && e.sessionId == "P" }; return false })
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    // MARK: M3 多回合 turn_ended 去抖(优先 subagentStop 为终态)

    @Test func hookChildTranscriptTurnEndedIsDebouncedUntilHookStop() {
        // 唯一 hook child 的 transcript turn_ended 不立即完成:优先等 subagentStop。
        let agg = CursorSubagentAggregator(transcriptStopDebounce: 5)
        let t0 = Date()
        _ = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStart",
                           cwd: nil, at: t0)
        // transcript 中途 turn_ended:仍视为运行中(去抖),父不抖到 thinking。
        guard case .event(let mid) = agg.ingest(
            parentId: "P", childId: "c1", cwd: nil, line: stopLine(),
            at: t0.addingTimeInterval(1))
        else { Issue.record("expected progress"); return }
        #expect(mid.name == "subagentProgress")
        #expect(agg.hasActiveChildren(parentId: "P"))
        // subagentStop 到达 → 权威终态,立即完成。
        let final = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStop",
                                   cwd: nil, at: t0.addingTimeInterval(2))
        guard case .event(let complete) = final else { Issue.record("expected completion"); return }
        #expect(complete.name == "subagentComplete")
    }

    @Test func tentativeStopRevivedByLaterChildActivity() {
        // turn_ended 后同一 child 又有活动 → 撤销试探性终态,不产生 running↔thinking 抖动。
        let agg = CursorSubagentAggregator(transcriptStopDebounce: 5)
        let t0 = Date()
        _ = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStart",
                           cwd: nil, at: t0)
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: stopLine(),
                       at: t0.addingTimeInterval(1))
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: toolLine(),
                       at: t0.addingTimeInterval(2))
        #expect(agg.hasActiveChildren(parentId: "P"))
        // 去抖窗口早已过,但 child 已被复活,不应再成熟为完成。
        let events = agg.prune(now: t0.addingTimeInterval(10))
        #expect(!events.contains { if case .event(let e) = $0 { return e.name == "subagentComplete" }; return false })
        #expect(agg.hasActiveChildren(parentId: "P"))
    }

    @Test func tentativeTranscriptStopMaturesAfterDebounceIfNoHookStop() {
        // 若 subagentStop 始终不来,去抖窗口过后 prune 使试探性终态成熟为完成,父不永久挂起。
        let agg = CursorSubagentAggregator(transcriptStopDebounce: 5)
        let t0 = Date()
        _ = agg.ingestHook(parentId: "P", childId: "c1", eventName: "subagentStart",
                           cwd: nil, at: t0)
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: stopLine(),
                       at: t0.addingTimeInterval(1))
        let events = agg.prune(now: t0.addingTimeInterval(1 + 5 + 1))
        #expect(events.contains { if case .event(let e) = $0 { return e.name == "subagentComplete" && e.sessionId == "P" }; return false })
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func transcriptOnlyChildStillCompletesImmediately() {
        // 无 hook 参与的 transcript-only child(本机常态)仍即时完成,不引入延迟。
        let agg = CursorSubagentAggregator(transcriptStopDebounce: 5)
        _ = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine())
        let final = agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: stopLine())
        guard case .event(let e) = final else { Issue.record("expected completion"); return }
        #expect(e.name == "subagentComplete")
        #expect(!agg.hasActiveChildren(parentId: "P"))
    }

    @Test func progressDoesNotRecordDuplicateToolCallBegin() {
        let store = SessionStore()
        let calls = Mutex<[(String, ToolCallPhase)]>([])
        store.toolCallObserver = { _, _, key, _, phase, _ in
            calls.withLock { $0.append((key, phase)) }
        }
        let agg = CursorSubagentAggregator()
        for _ in 0..<3 {
            store.apply(agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine()))
        }
        // subagentProgress(tool=Task)不应产生任何第三方工具 begin
        #expect(calls.withLock { $0 }.isEmpty)
    }

    @Test func completionDoesNotCloseUnrelatedToolCall() {
        let store = SessionStore()
        let calls = Mutex<[ToolCallPhase]>([])
        store.toolCallObserver = { _, _, _, _, phase, _ in
            calls.withLock { $0.append(phase) }
        }
        let agg = CursorSubagentAggregator()
        store.apply(agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: userLine()))
        store.apply(agg.ingest(parentId: "P", childId: "c1", cwd: nil, line: stopLine()))
        #expect(calls.withLock { $0 }.isEmpty)
        #expect(store.sessions.first(where: { $0.id == "P" })?.state == .thinking)
    }
}
