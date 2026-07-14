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
        CREATE TABLE IF NOT EXISTS tool_call(
            session_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            tool_key TEXT NOT NULL,
            tool_raw TEXT,
            called_at REAL NOT NULL,
            duration_sec REAL);
        CREATE INDEX IF NOT EXISTS idx_tool_kind_key ON tool_call(kind, tool_key);
        CREATE INDEX IF NOT EXISTS idx_tool_time ON tool_call(called_at);
        """)
        // 旧库升级:补 duration_sec 列(已存在则忽略错误)
        exec("ALTER TABLE tool_call ADD COLUMN duration_sec REAL")
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

    /// 单次工具调用时长上限(秒):超过视为丢了 end 事件,按上限计入
    static let toolCallCapSeconds = 600.0

    /// 第三方工具调用开始:先闭合该会话未完调用,再插入新行
    public func recordToolCallBegin(sessionId: String, kind: AgentKind,
                                    toolKey: String, toolRaw: String?,
                                    at date: Date = Date()) {
        guard !toolKey.isEmpty else { return }
        let ts = date.timeIntervalSince1970
        queue.async { [self] in
            closeOpenToolCalls(sessionId: sessionId, at: ts)
            run("""
            INSERT INTO tool_call(session_id, kind, tool_key, tool_raw, called_at, duration_sec)
            VALUES (?1, ?2, ?3, ?4, ?5, NULL)
            """, binds: [.text(sessionId), .text(kind.rawValue), .text(toolKey),
                         .text(toolRaw ?? ""), .real(ts)])
        }
    }

    /// 第三方工具调用结束:闭合该会话最近一条未完调用
    public func recordToolCallEnd(sessionId: String, toolKey: String?,
                                  at date: Date = Date()) {
        let ts = date.timeIntervalSince1970
        queue.async { [self] in
            closeOpenToolCalls(sessionId: sessionId, preferredKey: toolKey, at: ts)
        }
    }

    /// 兼容旧调用点:等价于 begin(无配对 end 时时长为 0)
    public func recordToolCall(sessionId: String, kind: AgentKind,
                               toolKey: String, toolRaw: String?,
                               at date: Date = Date()) {
        recordToolCallBegin(sessionId: sessionId, kind: kind,
                            toolKey: toolKey, toolRaw: toolRaw, at: date)
    }

    private func closeOpenToolCalls(sessionId: String, preferredKey: String? = nil,
                                    at ts: Double) {
        // 优先闭合匹配 tool_key 的未完行;否则闭合该会话任意未完行
        if let preferredKey, !preferredKey.isEmpty {
            run("""
            UPDATE tool_call
            SET duration_sec = MIN(\(Self.toolCallCapSeconds), MAX(0, ?1 - called_at))
            WHERE rowid = (
                SELECT rowid FROM tool_call
                WHERE session_id = ?2 AND tool_key = ?3 AND duration_sec IS NULL
                ORDER BY called_at DESC LIMIT 1
            )
            """, binds: [.real(ts), .text(sessionId), .text(preferredKey)])
        }
        run("""
        UPDATE tool_call
        SET duration_sec = MIN(\(Self.toolCallCapSeconds), MAX(0, ?1 - called_at))
        WHERE session_id = ?2 AND duration_sec IS NULL
        """, binds: [.real(ts), .text(sessionId)])
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

    /// 按 agent + tool_key 聚合调用次数、最近使用与累计时长
    public func toolUsage(kind: AgentKind? = nil, since: Date? = nil) -> [ToolUsageStat] {
        queue.sync {
            var sql = """
            SELECT tool_key, COUNT(*), MAX(called_at),
                   COALESCE(SUM(duration_sec), 0)
            FROM tool_call
            WHERE 1=1
            """
            var binds: [Bind] = []
            if let kind {
                sql += " AND kind = ?\(binds.count + 1)"
                binds.append(.text(kind.rawValue))
            }
            if let since {
                sql += " AND called_at >= ?\(binds.count + 1)"
                binds.append(.real(since.timeIntervalSince1970))
            }
            sql += " GROUP BY tool_key ORDER BY COUNT(*) DESC"
            return queryToolUsage(sql, binds: binds)
        }
    }

    /// 某 agent 在窗口内的总调用次数 + 累计时长 + 最近一次
    public func toolUsageSummary(kind: AgentKind, since: Date? = nil)
        -> (count: Int, lastUsedAt: Date?, totalDurationSeconds: Double) {
        queue.sync {
            var sql = """
            SELECT COUNT(*), MAX(called_at), COALESCE(SUM(duration_sec), 0)
            FROM tool_call WHERE kind = ?1
            """
            var binds: [Bind] = [.text(kind.rawValue)]
            if let since {
                sql += " AND called_at >= ?2"
                binds.append(.real(since.timeIntervalSince1970))
            }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
                return (0, nil, 0)
            }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, binds)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return (0, nil, 0) }
            let count = Int(sqlite3_column_int64(stmt, 0))
            let last = sqlite3_column_type(stmt, 1) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let duration = sqlite3_column_double(stmt, 2)
            return (count, last, duration)
        }
    }

    private func queryToolUsage(_ sql: String, binds: [Bind]) -> [ToolUsageStat] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, binds)
        var rows: [ToolUsageStat] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
            let key = String(cString: cStr)
            let count = Int(sqlite3_column_int64(stmt, 1))
            let last = sqlite3_column_type(stmt, 2) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            let duration = sqlite3_column_double(stmt, 3)
            rows.append(ToolUsageStat(toolKey: key, callCount: count,
                                      lastUsedAt: last, totalDurationSeconds: duration))
        }
        return rows
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
