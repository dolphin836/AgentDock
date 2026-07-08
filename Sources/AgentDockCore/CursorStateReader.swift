import Foundation
import SQLite3

/// Cursor 的会话指标存于全局存储 state.vscdb(cursorDiskKV 表)的
/// composerData:<conversationId> JSON:contextUsagePercent / contextTokensUsed /
/// modelConfig.modelName / workspaceIdentifier / lastUpdatedAt。
/// transcript 与 hook 事件里都没有这些指标,只能从这里补。只读查询,不碰写锁。
public enum CursorStateReader {

    public struct Snapshot: Sendable {
        public let sessions: [AgentSession]
        /// Task/best-of-N 派生的子 agent 会话 id,不应作为用户会话展示
        public let subagentIds: Set<String>
    }

    public static func defaultDatabasePath(home: String = NSHomeDirectory()) -> String {
        home + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }

    public enum PendingInteractionKind: Sendable {
        /// AskQuestion 提问卡片,等用户作答
        case question
        /// Auto-review 审批卡片(终端命令等),等用户批准/跳过
        case approval
    }

    public struct PendingInteraction: Sendable {
        public let sessionId: String
        public let bubbleId: String
        public let kind: PendingInteractionKind
        /// 审批的命令/拦截原因,提问的题干(可展示)
        public let detail: String?
    }

    /// 探测正在等用户处理的交互卡片。bubble 是实时写库的,挂起时 status='loading':
    /// - ask_question 工具 → 提问卡片
    /// - additionalData.smartModeApprovalRequestId 存在 → 审批卡片
    /// (transcript 的 assistant 行延迟落盘,这类信号只能从 bubble 拿)
    public static func pendingInteractions(dbPath: String,
                                           conversationIds: [String]) -> [PendingInteraction] {
        guard !conversationIds.isEmpty else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)

        // LIKE 先做粗筛(避免对每个 bubble 做 json_extract),再精确匹配挂起态
        let sql = """
        SELECT key,
               json_extract(value, '$.toolFormerData.name'),
               json_extract(value, '$.toolFormerData.additionalData.smartModeApprovalRequestId'),
               json_extract(value, '$.toolFormerData.params'),
               json_extract(value, '$.toolFormerData.additionalData.blockReason')
        FROM cursorDiskKV
        WHERE key > ? AND key < ?
          AND (value LIKE '%ask_question%' OR value LIKE '%smartModeApprovalRequestId%')
          AND json_extract(value, '$.toolFormerData.status') = 'loading'
        LIMIT 8
        """
        var pending: [PendingInteraction] = []
        for convId in conversationIds {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { continue }
            defer { sqlite3_finalize(stmt) }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, "bubbleId:\(convId):", -1, transient)
            sqlite3_bind_text(stmt, 2, "bubbleId:\(convId)~", -1, transient)
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let keyC = sqlite3_column_text(stmt, 0) else { continue }
                let key = String(cString: keyC)
                let bubbleId = (key as NSString).components(separatedBy: ":").last ?? key
                let tool = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                let approvalId = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                let params = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let blockReason = sqlite3_column_text(stmt, 4).map { String(cString: $0) }

                if let approvalId, !approvalId.isEmpty {
                    pending.append(PendingInteraction(
                        sessionId: convId, bubbleId: bubbleId, kind: .approval,
                        detail: Self.command(fromParams: params) ?? blockReason))
                } else if tool == "ask_question" {
                    pending.append(PendingInteraction(
                        sessionId: convId, bubbleId: bubbleId, kind: .question, detail: nil))
                }
            }
        }
        return pending
    }

    /// 查询指定 bubble 是否已被用户处理(status 不再是 loading / 行已不存在)。
    /// 主键点查,开销毫秒级,供挂起交互的高频监视器使用。
    public static func resolvedBubbleIds(dbPath: String,
                                         bubbles: [(sessionId: String, bubbleId: String)]) -> [String] {
        guard !bubbles.isEmpty else { return [] }
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return []
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)

        let sql = "SELECT json_extract(value, '$.toolFormerData.status') FROM cursorDiskKV WHERE key = ?1"
        var resolved: [String] = []
        for bubble in bubbles {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { continue }
            defer { sqlite3_finalize(stmt) }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(stmt, 1, "bubbleId:\(bubble.sessionId):\(bubble.bubbleId)", -1, transient)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let status = sqlite3_column_text(stmt, 0).map { String(cString: $0) }
                if status != "loading" { resolved.append(bubble.bubbleId) }
            } else {
                resolved.append(bubble.bubbleId)  // 行没了也视为已处理
            }
        }
        return resolved
    }

    /// 点查某会话是否为子 agent(composerData 带 subagentInfo / isBestOfNSubcomposer)。
    /// nil = 状态库还没有该会话的记录(刚创建),由调用方决定暂放行。
    public static func isSubagentConversation(dbPath: String, conversationId: String) -> Bool? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)

        let sql = """
        SELECT (json_extract(value, '$.subagentInfo') IS NOT NULL)
               OR (json_extract(value, '$.isBestOfNSubcomposer') = 1)
        FROM cursorDiskKV WHERE key = ?1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return nil }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, "composerData:\(conversationId)", -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return sqlite3_column_int(stmt, 0) == 1
    }

    static func command(fromParams params: String?) -> String? {
        guard let params,
              let obj = (try? JSONSerialization.jsonObject(with: Data(params.utf8))) as? [String: Any]
        else { return nil }
        return obj["command"] as? String
    }

    public static func recentConversations(dbPath: String,
                                           now: Date = Date(),
                                           maxAge: TimeInterval = 2 * 60 * 60) -> Snapshot {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return Snapshot(sessions: [], subagentIds: [])
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 200)

        let cutoffMs = Int64((now.timeIntervalSince1970 - maxAge) * 1000)
        let sql = """
        SELECT substr(key, 14),
               json_extract(value, '$.modelConfig.modelName'),
               json_extract(value, '$.contextUsagePercent'),
               json_extract(value, '$.contextTokensUsed'),
               json_extract(value, '$.lastUpdatedAt'),
               json_extract(value, '$.workspaceIdentifier.uri.fsPath'),
               json_extract(value, '$.isDraft'),
               json_extract(value, '$.isBestOfNSubcomposer'),
               json_extract(value, '$.subComposerIds'),
               json_extract(value, '$.subagentComposerIds')
        FROM cursorDiskKV
        WHERE key LIKE 'composerData:%'
          AND json_extract(value, '$.lastUpdatedAt') > ?
        LIMIT 100
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return Snapshot(sessions: [], subagentIds: [])
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, cutoffMs)

        var sessions: [AgentSession] = []
        var subagentIds: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idC = sqlite3_column_text(stmt, 0) else { continue }
            let id = String(cString: idC)
            // 父会话记录的子 composer 列表:无论父会话本身展不展示都要收集
            for column in [Int32(8), Int32(9)] {
                guard let arrC = sqlite3_column_text(stmt, column),
                      let arr = try? JSONSerialization.jsonObject(
                        with: Data(String(cString: arrC).utf8)) as? [String]
                else { continue }
                subagentIds.formUnion(arr)
            }
            let isDraft = sqlite3_column_int(stmt, 6) != 0
            let isSubcomposer = sqlite3_column_int(stmt, 7) != 0
            guard !isDraft, !isSubcomposer,
                  let cwdC = sqlite3_column_text(stmt, 5) else { continue }
            let cwd = String(cString: cwdC)

            var metrics = Metrics()
            if let modelC = sqlite3_column_text(stmt, 1) { metrics.model = String(cString: modelC) }
            if sqlite3_column_type(stmt, 2) != SQLITE_NULL {
                metrics.contextPct = Int(sqlite3_column_double(stmt, 2).rounded())
            }
            if sqlite3_column_type(stmt, 3) != SQLITE_NULL {
                metrics.totalTokens = Int(sqlite3_column_int64(stmt, 3))
            }
            let updatedMs = sqlite3_column_int64(stmt, 4)

            sessions.append(AgentSession(
                id: id, kind: .cursor,
                projectName: (cwd as NSString).lastPathComponent,
                cwd: cwd,
                // disconnected 永远不会被 backfill 采纳为状态,
                // 该来源只负责补指标/路径,状态由 transcript 推断与实时 hook 决定
                state: .disconnected,
                metrics: metrics,
                lastActivity: Date(timeIntervalSince1970: Double(updatedMs) / 1000)))
        }
        return Snapshot(sessions: sessions, subagentIds: subagentIds)
    }
}
