import Foundation

/// 扫描磁盘上的会话 transcript,为「App 启动前就已存在、还没发过事件」的会话补建条目。
/// 这些会话通常在等待用户输入(CLI/桌面端/编辑器插件都会落 transcript 文件)。
public enum SessionBackfillScanner {

    /// ~/.claude/projects/<project>/<session_id>.jsonl
    public static func scanClaude(projectsRoot: String,
                                  now: Date = Date(),
                                  maxAge: TimeInterval = 2 * 60 * 60) -> [AgentSession] {
        scan(root: projectsRoot, kind: .claudeCode, now: now, maxAge: maxAge)
    }

    /// ~/.codex/sessions/**/rollout-*.jsonl
    public static func scanCodex(root: String,
                                 now: Date = Date(),
                                 maxAge: TimeInterval = 2 * 60 * 60) -> [AgentSession] {
        scan(root: root, kind: .codex, now: now, maxAge: maxAge)
    }

    private static func scan(root: String, kind: AgentKind,
                             now: Date, maxAge: TimeInterval) -> [AgentSession] {
        guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [] }
        var sessions: [AgentSession] = []
        for case let rel as String in enumerator {
            guard rel.hasSuffix(".jsonl") else { continue }
            let path = (root as NSString).appendingPathComponent(rel)
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let mtime = attrs[.modificationDate] as? Date,
                  now.timeIntervalSince(mtime) < maxAge
            else { continue }
            var id = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension
            if kind == .codex { id = codexThreadId(fromRolloutName: id) }
            let cwd = extractCwd(path: path)
            // 隐藏目录下的会话是工具自动起的后台进程(如 claude-mem 的 observer),不是用户会话
            if let cwd, isHiddenPath(cwd) { continue }
            var state = SessionState.waitingInput
            var metrics: Metrics?
            switch kind {
            case .codex:
                let snapshot = codexTailSnapshot(path: path)
                state = snapshot.state ?? .waitingInput
                metrics = snapshot.metrics
            case .claudeCode:
                metrics = extractMetrics(path: path)
            case .cursor:
                break
            }
            sessions.append(AgentSession(
                id: id, kind: kind,
                projectName: cwd.map { ($0 as NSString).lastPathComponent } ?? kind.rawValue,
                cwd: cwd ?? "",
                state: state,
                metrics: metrics,
                lastActivity: mtime))
        }
        return sessions
    }

    /// ~/.cursor/projects/<项目slug>/agent-transcripts/**/<会话uuid>.jsonl
    /// slug 是把路径分隔符换成 "-" 的有损编码,需回猜真实 cwd;猜不出的(临时目录、
    /// empty-window 等)不是用户项目会话,跳过。
    public static func scanCursor(projectsRoot: String,
                                  now: Date = Date(),
                                  maxAge: TimeInterval = 2 * 60 * 60,
                                  excludedCwdPrefixes: [String] = ["/var/folders/", "/tmp/", "/private/"])
    -> [AgentSession] {
        guard let slugs = try? FileManager.default.contentsOfDirectory(atPath: projectsRoot) else { return [] }
        var sessions: [AgentSession] = []
        for slug in slugs {
            guard let cwd = resolvePathSlug(slug), !isHiddenPath(cwd),
                  !excludedCwdPrefixes.contains(where: { cwd.hasPrefix($0) })
            else { continue }
            let dir = (projectsRoot as NSString).appendingPathComponent(slug + "/agent-transcripts")
            guard let enumerator = FileManager.default.enumerator(atPath: dir) else { continue }
            // <会话>/subagents/ 下是 Task 派生的子 agent transcript,不是用户会话
            for case let rel as String in enumerator
            where rel.hasSuffix(".jsonl") && !rel.contains("subagents/") {
                let path = (dir as NSString).appendingPathComponent(rel)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let mtime = attrs[.modificationDate] as? Date,
                      now.timeIntervalSince(mtime) < maxAge
                else { continue }
                let id = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension
                // 无法判断聊天窗口是否还开着,默认 done 进「最近」;实时 hook 会纠正活跃态
                sessions.append(AgentSession(
                    id: id, kind: .cursor,
                    projectName: (cwd as NSString).lastPathComponent,
                    cwd: cwd,
                    state: inferCursorState(path: path) ?? .done,
                    lastActivity: mtime))
            }
        }
        return sessions
    }

    /// Cursor transcript 路径解析出的会话身份。
    public struct CursorTranscriptIdentity: Equatable, Sendable {
        /// 事件归属的会话 id:子 agent 用 child id,主会话用其本身 id。
        public let sessionId: String
        /// 父会话 id(子 agent 时非空;主会话为 nil)。
        public let parentId: String?
        public var isSubagent: Bool { parentId != nil }

        public init(sessionId: String, parentId: String?) {
            self.sessionId = sessionId
            self.parentId = parentId
        }
    }

    /// 从完整 transcript 路径解析父/子身份(纯函数,不碰文件系统):
    /// - 主会话:`.../agent-transcripts/<会话>/<会话>.jsonl` → sessionId=会话,parentId=nil
    /// - 子会话:`.../agent-transcripts/<父>/subagents/<子>.jsonl` → sessionId=子,parentId=父
    /// 定位 "subagents" 组件,其前一层即父目录名,兼容更深的嵌套路径。
    public static func cursorTranscriptIdentity(path: String) -> CursorTranscriptIdentity {
        let comps = (path as NSString).pathComponents
        let file = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        if let subIdx = comps.firstIndex(of: "subagents"), subIdx > 0 {
            return CursorTranscriptIdentity(sessionId: file, parentId: comps[subIdx - 1])
        }
        return CursorTranscriptIdentity(sessionId: file, parentId: nil)
    }

    /// "Users-eric-Work-Code-platform-debit-card" → "/Users/eric/Work/Code/platform-debit-card"。
    /// "-" 既可能是路径分隔也可能是目录名的一部分,按文件系统实际存在的目录回溯猜解。
    public static func resolvePathSlug(
        _ slug: String,
        directoryExists: (String) -> Bool = { path in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }
    ) -> String? {
        let parts = slug.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1, !parts[0].isEmpty else { return nil }
        func search(_ index: Int, _ current: String) -> String? {
            if index == parts.count {
                return directoryExists(current) ? current : nil
            }
            // 优先当作更深一层目录;当前前缀必须真实存在才值得下钻
            if directoryExists(current),
               let hit = search(index + 1, current + "/" + parts[index]) { return hit }
            // 否则视为目录名内的连字符
            return search(index + 1, current + "-" + parts[index])
        }
        return search(1, "/" + parts[0])
    }

    /// 从 Cursor transcript 尾部倒推状态:turn_ended → done;
    /// assistant 带 tool_use → runningTool;user/assistant 纯文本 → thinking(回合进行中)。
    public static func inferCursorState(path: String) -> SessionState? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }
        let readLen = min(size, 256 * 1024)
        try? handle.seek(toOffset: size - readLen)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        for lineData in data.split(separator: UInt8(ascii: "\n")).reversed() {
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(lineData))) as? [String: Any]
            else { continue }
            if obj["type"] as? String == "turn_ended" { return .done }
            guard let role = obj["role"] as? String else { continue }
            if role == "user" { return .thinking }
            if role == "assistant" {
                let content = (obj["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
                let hasToolUse = content.contains { $0["type"] as? String == "tool_use" }
                return hasToolUse ? .runningTool : .thinking
            }
        }
        return nil
    }

    /// cwd 中任一路径组件以 "." 开头即视为隐藏目录(如 ~/.claude-mem/observer-sessions)
    public static func isHiddenPath(_ path: String) -> Bool {
        path.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    /// rollout 文件名形如 rollout-<YYYY-MM-DDTHH-mm-ss>-<thread-uuid>,提取 uuid 作为
    /// sessionId,与 SQLite threads.id / notify 的 thread-id 对齐——否则同一会话
    /// 会以两种 id 出现两条。不匹配该格式时原样返回。
    public static func codexThreadId(fromRolloutName name: String) -> String {
        let prefix = #"^rollout-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-"#
        let stripped = name.replacingOccurrences(of: prefix, with: "", options: .regularExpression)
        return stripped.isEmpty ? name : stripped
    }

    /// 从 transcript 尾部提取最近一条 assistant 消息的 usage/model,补齐离线会话的指标。
    /// (格式属 Claude Code 内部实现,解析失败一律返回 nil,不影响会话本身)
    static func extractMetrics(path: String) -> Metrics? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }
        let readLen = min(size, 256 * 1024)
        try? handle.seek(toOffset: size - readLen)
        guard let data = try? handle.readToEnd() else { return nil }

        for lineData in data.split(separator: UInt8(ascii: "\n")).reversed() {
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(lineData))) as? [String: Any],
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { continue }
            let input = usage["input_tokens"] as? Int ?? 0
            let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
            let cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
            let output = usage["output_tokens"] as? Int ?? 0
            guard input + cacheRead + cacheWrite + output > 0 else { continue }
            var m = Metrics()
            m.model = message["model"] as? String
            m.totalTokens = input + cacheRead + cacheWrite + output
            // 近似 ctx 占比:按 200k 窗口估算(离线拿不到真实窗口大小)
            m.contextPct = min(100, (input + cacheRead + cacheWrite) * 100 / 200_000)
            return m
        }
        return nil
    }

    /// 从 Codex rollout 尾部重放:状态事件推断当前状态(避免已完成的历史线程被
    /// 误判成 waitingInput),token_count 事件提取 ctx/tokens 指标。
    public static func codexTailSnapshot(path: String) -> (state: SessionState?, metrics: Metrics?) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return (nil, nil) }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd(), size > 0 else { return (nil, nil) }
        let readLen = min(size, 256 * 1024)
        try? handle.seek(toOffset: size - readLen)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return (nil, nil) }

        var state = SessionState.waitingInput
        var sawStateEvent = false
        var metrics: Metrics?
        for lineData in data.split(separator: UInt8(ascii: "\n")) where !lineData.isEmpty {
            switch EventIngestor.parseCodexRolloutLine(
                sessionId: "codex-backfill", cwd: nil, line: Data(lineData)) {
            case .event(let event):
                let next = mapEventToState(event, current: state)
                if next != state {
                    sawStateEvent = true
                    state = next
                }
            case .metrics(_, _, let m, _):
                metrics = m  // 取最后一条 token_count
            case .ignored:
                continue
            }
        }
        return (sawStateEvent ? state : nil, metrics)
    }

    public static func inferCodexState(path: String) -> SessionState? {
        codexTailSnapshot(path: path).state
    }

    /// transcript 头部一般带 "cwd":"..." 字段,取前 16KB 正则提取
    private static func extractCwd(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path),
              let data = try? handle.read(upToCount: 16 * 1024) else { return nil }
        try? handle.close()
        let text = String(decoding: data, as: UTF8.self)
        guard let range = text.range(of: #""cwd"\s*:\s*"([^"]+)""#, options: .regularExpression)
        else { return nil }
        let match = String(text[range])
        return match.replacingOccurrences(of: #""cwd"\s*:\s*""#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
