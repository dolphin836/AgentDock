import Foundation
import SQLite3

/// 本地活动历史库(~/.agentdock/history.sqlite):记录会话状态区间与 token 采样,
/// 支撑「今日/本周工作时长、token 消耗、等待介入」统计。
/// 全部操作在专属串行队列上执行,写入为 fire-and-forget,不阻塞事件链路。
public final class HistoryStore: @unchecked Sendable {

    public struct ActivityStats: Sendable, Equatable {
        /// agent 处于思考/执行状态的总时长(秒)
        public var activeSeconds: Double = 0
        /// token 消耗近似值(按各会话 context token 的正增量累加)
        public var approxTokens: Int = 0
        /// 等待用户介入的次数(等输入/等审批区间)
        public var waitCount: Int = 0
        /// 平均等待时长(秒,单次封顶 30 分钟避免挂机失真)
        public var avgWaitSeconds: Double = 0
    }

    private let queue = DispatchQueue(label: "agentdock.history", qos: .utility)
    private var db: OpaquePointer?
    /// 单次等待计入上限:超过视为用户不在场,不该算进「让 agent 等了多久」
    static let waitCapSeconds = 1800.0

    public init(path: String) {
        queue.sync { open(path) }
    }

    deinit {
        sqlite3_close(db)
    }

    private func open(_ path: String) {
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            sqlite3_close(db)
            db = nil
            return
        }
        sqlite3_busy_timeout(db, 500)
        exec("""
        CREATE TABLE IF NOT EXISTS state_span(
            session_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            project TEXT NOT NULL,
            state TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL);
        CREATE INDEX IF NOT EXISTS idx_span_session ON state_span(session_id, ended_at);
        CREATE INDEX IF NOT EXISTS idx_span_time ON state_span(started_at);
        CREATE TABLE IF NOT EXISTS token_sample(
            session_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            sampled_at REAL NOT NULL,
            total_tokens INTEGER NOT NULL);
        CREATE INDEX IF NOT EXISTS idx_token_time ON token_sample(sampled_at);
        """)
        // 上次运行遗留的未闭合区间:真实时长未知,按零时长闭合(诚实地少计而不虚增)
        exec("UPDATE state_span SET ended_at = started_at WHERE ended_at IS NULL")
    }

    // MARK: - 写入

    /// 状态转换:闭合该会话的未完区间,若有新状态则开新区间。to = nil 表示会话被移除。
    public func recordTransition(sessionId: String, kind: AgentKind, project: String,
                                 to state: SessionState?, at date: Date = Date()) {
        let ts = date.timeIntervalSince1970
        queue.async { [self] in
            run("UPDATE state_span SET ended_at = ?1 WHERE session_id = ?2 AND ended_at IS NULL",
                binds: [.real(ts), .text(sessionId)])
            if let state {
                run("""
                INSERT INTO state_span(session_id, kind, project, state, started_at, ended_at)
                VALUES (?1, ?2, ?3, ?4, ?5, NULL)
                """, binds: [.text(sessionId), .text(kind.rawValue), .text(project),
                             .text(state.rawValue), .real(ts)])
            }
        }
    }

    public func recordTokens(sessionId: String, kind: AgentKind, tokens: Int,
                             at date: Date = Date()) {
        let ts = date.timeIntervalSince1970
        queue.async { [self] in
            run("INSERT INTO token_sample(session_id, kind, sampled_at, total_tokens) VALUES (?1, ?2, ?3, ?4)",
                binds: [.text(sessionId), .text(kind.rawValue), .real(ts), .int(tokens)])
        }
    }

    /// 等待队列中的写入全部落盘(测试/退出前用)
    public func flush() {
        queue.sync {}
    }

    // MARK: - 统计

    public func stats(since: Date, now: Date = Date()) -> ActivityStats {
        let start = since.timeIntervalSince1970
        let end = now.timeIntervalSince1970
        return queue.sync {
            var result = ActivityStats()
            result.activeSeconds = scalarDouble("""
            SELECT COALESCE(SUM(MIN(COALESCE(ended_at, ?2), ?2) - MAX(started_at, ?1)), 0)
            FROM state_span
            WHERE state IN ('thinking', 'runningTool')
              AND COALESCE(ended_at, ?2) > ?1 AND started_at < ?2
            """, start: start, end: end)

            let waits = rowDoubles("""
            SELECT COUNT(*), COALESCE(SUM(MIN(dur, \(Self.waitCapSeconds))), 0) FROM (
                SELECT MIN(COALESCE(ended_at, ?2), ?2) - MAX(started_at, ?1) AS dur
                FROM state_span
                WHERE state IN ('waitingInput', 'waitingApproval')
                  AND COALESCE(ended_at, ?2) > ?1 AND started_at < ?2
            ) WHERE dur > 0
            """, start: start, end: end)
            result.waitCount = Int(waits.first ?? 0)
            let totalWait = waits.count > 1 ? waits[1] : 0
            result.avgWaitSeconds = result.waitCount > 0 ? totalWait / Double(result.waitCount) : 0

            result.approxTokens = Int(scalarDouble("""
            SELECT COALESCE(SUM(delta), 0) FROM (
                SELECT total_tokens - LAG(total_tokens)
                    OVER (PARTITION BY session_id ORDER BY sampled_at) AS delta
                FROM token_sample
                WHERE sampled_at >= ?1 AND sampled_at < ?2
            ) WHERE delta > 0
            """, start: start, end: end))
            return result
        }
    }

    // MARK: - SQLite 基础

    private enum Bind {
        case text(String), real(Double), int(Int)
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func run(_ sql: String, binds: [Bind]) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, binds)
        sqlite3_step(stmt)
    }

    private func bind(_ stmt: OpaquePointer, _ binds: [Bind]) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, value) in binds.enumerated() {
            let index = Int32(i + 1)
            switch value {
            case .text(let s): sqlite3_bind_text(stmt, index, s, -1, transient)
            case .real(let d): sqlite3_bind_double(stmt, index, d)
            case .int(let n): sqlite3_bind_int64(stmt, index, Int64(n))
            }
        }
    }

    private func scalarDouble(_ sql: String, start: Double, end: Double) -> Double {
        rowDoubles(sql, start: start, end: end).first ?? 0
    }

    private func rowDoubles(_ sql: String, start: Double, end: Double) -> [Double] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, start)
        sqlite3_bind_double(stmt, 2, end)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return [] }
        return (0..<sqlite3_column_count(stmt)).map { sqlite3_column_double(stmt, $0) }
    }
}
