import Foundation
import SQLite3

/// 新版 Codex 的 thread 索引存于 ~/.codex/state_*.sqlite。
/// 只读查询 threads 表,并借 rollout_path 回看尾部事件推断当前状态。
public enum CodexStateReader {

    /// 在 ~/.codex 下找最新的 state_*.sqlite
    public static func findDatabase(codexRoot: String) -> String? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: codexRoot) else { return nil }
        return names
            .filter { $0.hasPrefix("state_") && $0.hasSuffix(".sqlite") }
            .map { (codexRoot as NSString).appendingPathComponent($0) }
            .max { mtime($0) < mtime($1) }
    }

    private static func mtime(_ path: String) -> Date {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
            ?? .distantPast
    }

    public static func recentThreads(dbPath: String,
                                     now: Date = Date(),
                                     maxAge: TimeInterval = 2 * 60 * 60) -> [AgentSession] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)

        let cutoffMs = Int64((now.timeIntervalSince1970 - maxAge) * 1000)
        let sql = """
        SELECT id, cwd, model, rollout_path, recency_at_ms FROM threads
        WHERE archived = 0 AND recency_at_ms > ? ORDER BY recency_at_ms DESC LIMIT 50
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, cutoffMs)

        var sessions: [AgentSession] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0),
                  let cwdC = sqlite3_column_text(stmt, 1) else { continue }
            let cwd = String(cString: cwdC)
            let model = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            let rolloutPath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let recencyMs = sqlite3_column_int64(stmt, 4)
            // 状态与 ctx/tokens 都从 rollout 尾部拿(token_count 事件);模型名来自表
            let snapshot = rolloutPath.map { SessionBackfillScanner.codexTailSnapshot(path: $0) }
            var metrics = snapshot?.metrics ?? Metrics()
            if metrics.model == nil { metrics.model = model }
            sessions.append(AgentSession(
                id: String(cString: idC), kind: .codex,
                projectName: (cwd as NSString).lastPathComponent,
                cwd: cwd,
                state: snapshot?.state ?? .waitingInput,
                metrics: metrics,
                lastActivity: Date(timeIntervalSince1970: Double(recencyMs) / 1000)))
        }
        return sessions
    }
}
