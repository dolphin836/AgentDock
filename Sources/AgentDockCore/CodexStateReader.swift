import Foundation
import SQLite3

/// 新版 Codex(Desktop 0.138+)不再写 rollout JSONL,会话状态存于 ~/.codex/state_*.sqlite。
/// 只读查询 threads 表,把近期活跃的线程映射为会话。
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
        SELECT id, cwd, model, recency_at_ms FROM threads
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
            let recencyMs = sqlite3_column_int64(stmt, 3)
            sessions.append(AgentSession(
                id: String(cString: idC), kind: .codex,
                projectName: (cwd as NSString).lastPathComponent,
                cwd: cwd,
                state: .waitingInput,
                metrics: model.map { Metrics(model: $0) },
                lastActivity: Date(timeIntervalSince1970: Double(recencyMs) / 1000)))
        }
        return sessions
    }
}
