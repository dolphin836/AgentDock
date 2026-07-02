import Foundation
import Observation

@MainActor
@Observable
public final class SessionStore {
    public private(set) var sessions: [AgentSession] = []

    /// 无活动超过该时长 → disconnected
    public var disconnectAfter: TimeInterval = 30 * 60
    /// 无活动超过该时长 → 从列表移除
    public var removeAfter: TimeInterval = 2 * 60 * 60
    /// 事件环形缓冲上限
    public static let maxRecentEvents = 20

    public init() {}

    public func apply(_ result: IngestResult) {
        switch result {
        case .ignored:
            return
        case .event(let event):
            var session = sessions.first(where: { $0.id == event.sessionId })
                ?? AgentSession(
                    id: event.sessionId, kind: event.kind,
                    projectName: Self.projectName(from: event.cwd),
                    cwd: event.cwd ?? "", state: .idle)
            if let cwd = event.cwd, !cwd.isEmpty {
                session.cwd = cwd
                session.projectName = Self.projectName(from: cwd)
            }
            session.state = mapEventToState(event, current: session.state)
            session.recentEvents.append(event)
            if session.recentEvents.count > Self.maxRecentEvents {
                session.recentEvents.removeFirst(session.recentEvents.count - Self.maxRecentEvents)
            }
            session.lastActivity = event.timestamp
            upsert(session)
        case .metrics(let sessionId, let metrics):
            guard var session = sessions.first(where: { $0.id == sessionId }) else { return }
            session.metrics = metrics
            session.lastActivity = Date()
            upsert(session)
        }
    }

    public func prune(now: Date = Date()) {
        sessions.removeAll { now.timeIntervalSince($0.lastActivity) > removeAfter }
        for i in sessions.indices
        where now.timeIntervalSince(sessions[i].lastActivity) > disconnectAfter {
            sessions[i].state = .disconnected
        }
    }

    private func upsert(_ session: AgentSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        sessions.sort { $0.lastActivity > $1.lastActivity }
    }

    static func projectName(from cwd: String?) -> String {
        guard let cwd, !cwd.isEmpty else { return "unknown" }
        return (cwd as NSString).lastPathComponent
    }
}
