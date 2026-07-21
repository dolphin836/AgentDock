import Testing
import Foundation
@testable import AgentDockCore

@MainActor
@Suite struct CursorHookEventDeduplicatorTests {
    private func event(session: String = "conv-1", name: String = "preToolUse",
                       tool: String? = "Shell", detail: String? = "ls") -> AgentEvent {
        AgentEvent(sessionId: session, kind: .cursor, name: name, detail: detail, tool: tool)
    }

    @Test func exactDuplicateIsConsumedOnce() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let hook = event()
        let t0 = Date()
        deduplicator.record(hook, at: t0)

        #expect(deduplicator.consumeDuplicate(event(), at: t0.addingTimeInterval(1)))
        // 一个 hook 指纹只消费一条 transcript；下一次同类动作没有 hook 时必须放行。
        #expect(!deduplicator.consumeDuplicate(event(), at: t0.addingTimeInterval(2)))
    }

    @Test func queuedHooksConsumeMatchingTranscriptOneForOne() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        deduplicator.record(event(), at: t0)
        deduplicator.record(event(), at: t0.addingTimeInterval(0.1))

        #expect(deduplicator.consumeDuplicate(event(), at: t0.addingTimeInterval(1)))
        #expect(deduplicator.consumeDuplicate(event(), at: t0.addingTimeInterval(2)))
        #expect(!deduplicator.consumeDuplicate(event(), at: t0.addingTimeInterval(3)))
    }

    @Test func fingerprintIsolatesSessionEventAndStableToolButNotDetail() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        deduplicator.record(event(), at: t0)

        #expect(!deduplicator.consumeDuplicate(
            event(session: "conv-2"), at: t0.addingTimeInterval(1)))
        #expect(!deduplicator.consumeDuplicate(
            event(name: "postToolUse"), at: t0.addingTimeInterval(1)))
        #expect(!deduplicator.consumeDuplicate(
            event(tool: "Read"), at: t0.addingTimeInterval(1)))
        // detail 来自不同通道，命令/文件名等经常不一致，不参与指纹。
        #expect(deduplicator.consumeDuplicate(
            event(detail: "pwd"), at: t0.addingTimeInterval(1)))
    }

    @Test func expiredFingerprintIsPruned() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        deduplicator.record(event(), at: t0)
        #expect(!deduplicator.consumeDuplicate(event(), at: t0.addingTimeInterval(6)))
        #expect(deduplicator.pendingCount == 0)
    }

    @Test func cacheIsBounded() {
        let deduplicator = CursorHookEventDeduplicator(window: 60, maxRecords: 3)
        let t0 = Date()
        for index in 0..<10 {
            deduplicator.record(
                event(session: "conv-\(index)", detail: "\(index)"),
                at: t0.addingTimeInterval(Double(index) / 10))
        }
        #expect(deduplicator.pendingCount == 3)
    }

    @Test func realCursorHookAndTranscriptToolEventsDeduplicate() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()

        func hook(_ payload: String) -> AgentEvent {
            let line = Data("""
            {"source":"cursor","type":"hook","payload":\(payload)}
            """.utf8)
            guard case .event(let event) = EventIngestor.parseLine(line) else {
                Issue.record("expected hook event")
                return event()
            }
            return event
        }
        func transcript(_ json: String) -> AgentEvent {
            guard case .event(let event) = EventIngestor.parseCursorTranscriptLine(
                sessionId: "conv-1", cwd: "/x/p", line: Data(json.utf8)) else {
                Issue.record("expected transcript event")
                return self.event()
            }
            return event
        }

        let shellHook = hook(#"{"conversation_id":"conv-1","hook_event_name":"preToolUse","tool_name":"Shell","tool_use_id":"tool-1","tool_input":{"command":"swift test"}}"#)
        let shellTranscript = transcript(#"{"role":"assistant","message":{"content":[{"type":"tool_use","id":"tool-1","name":"Shell"}]}}"#)
        #expect(shellHook.detail == "swift test")
        #expect(shellTranscript.detail == "Shell")
        deduplicator.record(shellHook, at: t0)
        #expect(deduplicator.consumeDuplicate(shellTranscript, at: t0.addingTimeInterval(1)))
        // 相同类型下一次没有 hook，不能继续压制。
        #expect(!deduplicator.consumeDuplicate(shellTranscript, at: t0.addingTimeInterval(2)))

        let readHook = hook(#"{"conversation_id":"conv-1","hook_event_name":"preToolUse","tool_name":"Read","tool_input":{"file_path":"/tmp/a.swift"}}"#)
        let readTranscript = transcript(#"{"role":"assistant","message":{"content":[{"type":"tool_use","name":"Read"}]}}"#)
        deduplicator.record(readHook, at: t0)
        #expect(deduplicator.consumeDuplicate(readTranscript, at: t0.addingTimeInterval(1)))

        let mcpHook = hook(#"{"conversation_id":"conv-1","hook_event_name":"preToolUse","tool_name":"CallMcpTool","tool_call_id":"mcp-1","tool_input":{"server":"notion","toolName":"search"}}"#)
        let mcpTranscript = transcript(#"{"role":"assistant","message":{"content":[{"type":"tool_use","id":"mcp-1","name":"CallMcpTool"}]}}"#)
        deduplicator.record(mcpHook, at: t0)
        #expect(deduplicator.consumeDuplicate(mcpTranscript, at: t0.addingTimeInterval(1)))
    }

    // MARK: M2 双向去重(hook / transcript 任一先到都只 apply 一次)

    @Test func transcriptFirstThenHookIsDeduped() {
        // transcript 先到:先登记(自身通道),随后 hook 到达发现对侧已 apply → 判重丢弃。
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        deduplicator.record(event(), channel: .transcript, at: t0)
        #expect(deduplicator.consumeDuplicate(event(), ownChannel: .hook, at: t0.addingTimeInterval(1)))
        // 只压制一条;同类型下一次没有对侧记录时放行。
        #expect(!deduplicator.consumeDuplicate(event(), ownChannel: .hook, at: t0.addingTimeInterval(2)))
    }

    @Test func hookFirstThenTranscriptIsDeduped() {
        // 既有方向仍成立:hook 先到,transcript 判重。
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        deduplicator.record(event(), channel: .hook, at: t0)
        #expect(deduplicator.consumeDuplicate(event(), ownChannel: .transcript, at: t0.addingTimeInterval(1)))
        #expect(!deduplicator.consumeDuplicate(event(), ownChannel: .transcript, at: t0.addingTimeInterval(2)))
    }

    @Test func sameChannelDoesNotSelfConsume() {
        // 同通道两条(如两次相邻 hook)不得互相判重,否则会漏掉对侧 transcript 的去重记录。
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        deduplicator.record(event(), channel: .hook, at: t0)
        #expect(!deduplicator.consumeDuplicate(event(), ownChannel: .hook, at: t0.addingTimeInterval(1)))
    }

    @Test func correlationIdTakesPriorityWhenBothSidesProvideIt() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        let hook = AgentEvent(sessionId: "c", kind: .cursor, name: "preToolUse",
                              tool: "Shell", correlationId: "hook-id")
        let other = AgentEvent(sessionId: "c", kind: .cursor, name: "preToolUse",
                               tool: "Shell", correlationId: "other-id")
        deduplicator.record(hook, at: t0)
        #expect(!deduplicator.consumeDuplicate(other, at: t0.addingTimeInterval(1)))
        #expect(deduplicator.consumeDuplicate(hook, at: t0.addingTimeInterval(1)))
    }

    @Test func postAndStopUseSessionNameFIFO() {
        let deduplicator = CursorHookEventDeduplicator(window: 5)
        let t0 = Date()
        func hook(_ payload: String) -> AgentEvent {
            let line = Data("""
            {"source":"cursor","type":"hook","payload":\(payload)}
            """.utf8)
            guard case .event(let event) = EventIngestor.parseLine(line) else {
                Issue.record("expected hook event")
                return AgentEvent(sessionId: "c", kind: .cursor, name: "invalid")
            }
            return event
        }
        func transcript(_ json: String) -> AgentEvent {
            guard case .event(let event) = EventIngestor.parseCursorTranscriptLine(
                sessionId: "c", cwd: nil, line: Data(json.utf8)) else {
                Issue.record("expected transcript event")
                return AgentEvent(sessionId: "c", kind: .cursor, name: "invalid")
            }
            return event
        }
        let postHook = hook(#"{"conversation_id":"c","hook_event_name":"postToolUse","tool_name":"Shell","tool_input":{"command":"pwd"}}"#)
        let postTranscript = transcript(#"{"role":"assistant","message":{"content":[{"type":"text","text":"done"}]}}"#)
        deduplicator.record(postHook, at: t0)
        deduplicator.record(postHook, at: t0.addingTimeInterval(0.1))
        #expect(deduplicator.consumeDuplicate(postTranscript, at: t0.addingTimeInterval(1)))
        #expect(deduplicator.consumeDuplicate(postTranscript, at: t0.addingTimeInterval(2)))
        #expect(!deduplicator.consumeDuplicate(postTranscript, at: t0.addingTimeInterval(3)))

        let stopHook = hook(#"{"conversation_id":"c","hook_event_name":"stop","tool_name":"Task"}"#)
        let stopTranscript = transcript(#"{"type":"turn_ended","status":"success"}"#)
        deduplicator.record(stopHook, at: t0)
        #expect(deduplicator.consumeDuplicate(stopTranscript, at: t0.addingTimeInterval(1)))
    }
}
