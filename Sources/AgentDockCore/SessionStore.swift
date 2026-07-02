import Foundation
import Observation

@MainActor
@Observable
public final class SessionStore {
    public private(set) var sessions: [AgentSession] = []

    /// 无活动超过该时长 → disconnected
    public var disconnectAfter: TimeInterval = 10 * 60
    /// 无活动超过该时长 → 从列表移除
    public var removeAfter: TimeInterval = 2 * 60 * 60
    /// 事件环形缓冲上限
    public static let maxRecentEvents = 20

    /// Claude 会话准入校验(注册表过滤子 agent / 工具会话);nil = 不过滤
    public var claudeSessionValidator: ((String) -> Bool)?

    /// 账号级限额(展开面板顶部展示)
    public private(set) var claudeRateLimits: RateLimits?
    public var codexRateLimits: RateLimits?

    public init() {}

    public func apply(_ result: IngestResult) {
        switch result {
        case .ignored:
            return
        case .event(let event):
            // 隐藏目录下的后台工具会话(如 claude-mem observer)不展示
            if let cwd = event.cwd, SessionBackfillScanner.isHiddenPath(cwd) { return }
            // 未注册的 claude 会话(后台子 agent)不展示
            if event.kind == .claudeCode,
               let validator = claudeSessionValidator, !validator(event.sessionId) { return }
            var session = sessions.first(where: { $0.id == event.sessionId })
                ?? AgentSession(
                    id: event.sessionId, kind: event.kind,
                    projectName: Self.projectName(from: event.cwd),
                    cwd: event.cwd ?? "", state: .idle)
            if let cwd = event.cwd, !cwd.isEmpty {
                session.cwd = cwd
                session.projectName = Self.projectName(from: cwd)
            }
            if let app = event.appPath { session.appPath = app }
            session.state = mapEventToState(event, current: session.state)
            session.recentEvents.append(event)
            if session.recentEvents.count > Self.maxRecentEvents {
                session.recentEvents.removeFirst(session.recentEvents.count - Self.maxRecentEvents)
            }
            session.lastActivity = event.timestamp
            upsert(session)
        case .metrics(let sessionId, let metrics, let limits):
            if let limits { claudeRateLimits = limits }
            guard var session = sessions.first(where: { $0.id == sessionId }) else { return }
            session.metrics = metrics
            session.lastActivity = Date()
            upsert(session)
        }
    }

    /// 回填磁盘扫描到的会话:不存在则插入;已存在但磁盘更新(transcript 有新写入)
    /// 且当前没有更新的实时事件时,刷新活跃时间并把 disconnected 拉回 waitingInput。
    public func backfill(_ scanned: [AgentSession]) {
        // 注册表变化时(子 agent 结束、会话退出),清掉已不合法的 claude 会话
        if let validator = claudeSessionValidator {
            sessions.removeAll { $0.kind == .claudeCode && !validator($0.id) }
        }
        for candidate in scanned {
            if candidate.kind == .claudeCode,
               let validator = claudeSessionValidator, !validator(candidate.id) { continue }
            if let i = sessions.firstIndex(where: { $0.id == candidate.id }) {
                if candidate.lastActivity > sessions[i].lastActivity {
                    // 磁盘比内存新:会话在别处有了新动静,刷新活跃时间和指标
                    sessions[i].lastActivity = candidate.lastActivity
                    if let m = candidate.metrics { sessions[i].metrics = m }
                    if sessions[i].state == .disconnected {
                        sessions[i].state = .waitingInput
                    }
                } else if sessions[i].metrics == nil, let m = candidate.metrics {
                    // 内存较新但从没拿到过指标:用磁盘提取的补上
                    sessions[i].metrics = m
                }
            } else {
                sessions.append(candidate)
            }
        }
        sessions.sort { $0.lastActivity > $1.lastActivity }
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
