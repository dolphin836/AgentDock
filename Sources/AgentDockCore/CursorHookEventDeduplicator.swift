import Foundation

/// Cursor hook 与 transcript 对同一原生事件的短时一次性去重器。
///
/// hook 先到时记录稳定事件指纹(session/name/correlationId 或 tool)；transcript 后到时
/// 只消费一条匹配记录。这样同类型的下一次动作若没有对应 hook 会正常放行，
/// 不会被「通道健康」概念整段压制。
/// 缓存同时受过期窗口与条数上限约束。
///
/// 仅在主线程访问(AppDelegate 持有),不做并发保护。
@MainActor
public final class CursorHookEventDeduplicator {
    /// 事件来源通道:双向去重时,一条记录只被**对侧**通道消费。
    public enum Channel: Sendable { case hook, transcript }

    private struct Record {
        let sessionId: String
        let eventName: String
        let tool: String?
        let correlationId: String?
        let channel: Channel
        let timestamp: Date

        init(_ event: AgentEvent, channel: Channel, at: Date) {
            sessionId = event.sessionId
            eventName = event.name
            tool = Self.stableTool(for: event)
            correlationId = event.correlationId
            self.channel = channel
            timestamp = at
        }

        private static func stableTool(for event: AgentEvent) -> String? {
            // transcript 只对 tool_use 提供稳定工具名；post/stop/submit 等按 session+name FIFO。
            event.name == "preToolUse" ? event.tool : nil
        }
    }

    private var records: [Record] = []
    private let window: TimeInterval
    private let maxRecords: Int

    public init(window: TimeInterval = 5, maxRecords: Int = 512) {
        self.window = window
        self.maxRecords = max(1, maxRecords)
    }

    /// 某通道事件到达时排队;同一指纹可同时保留多条,随后由对侧逐条消费。
    /// 默认 `.hook` 以兼容既有调用。
    public func record(_ event: AgentEvent, channel: Channel = .hook, at: Date = Date()) {
        prune(at: at)
        records.append(Record(event, channel: channel, at: at))
        if records.count > maxRecords {
            records.remove(at: records.indices.min(by: {
                records[$0].timestamp < records[$1].timestamp
            }) ?? records.startIndex)
        }
    }

    /// 到达事件是否为对侧通道已 apply 的重复:消费一条窗口内、**非本通道**的精确匹配记录。
    /// `ownChannel` 默认 `.transcript`(既有的 hook→transcript 去重方向)。
    public func consumeDuplicate(_ event: AgentEvent, ownChannel: Channel = .transcript,
                                 at: Date = Date()) -> Bool {
        prune(at: at)
        guard let index = records.firstIndex(where: {
            let age = at.timeIntervalSince($0.timestamp)
            return age >= 0 && age < window && $0.channel != ownChannel && matches($0, event)
        }) else { return false }
        records.remove(at: index)
        return true
    }

    /// 主动清理过期记录；record/consume 也会自动调用。
    public func prune(at: Date = Date()) {
        records.removeAll { at.timeIntervalSince($0.timestamp) >= window }
    }

    /// 供测试验证缓存上限，不暴露具体指纹内容。
    var pendingCount: Int {
        records.count
    }

    private func matches(_ record: Record, _ event: AgentEvent) -> Bool {
        guard record.sessionId == event.sessionId,
              record.eventName == event.name else { return false }
        if let recordedId = record.correlationId, let incomingId = event.correlationId {
            return recordedId == incomingId
        }
        let incomingTool = event.name == "preToolUse" ? event.tool : nil
        return record.tool == incomingTool
    }
}
