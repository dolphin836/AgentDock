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
            let id = ((rel as NSString).lastPathComponent as NSString).deletingPathExtension
            let cwd = extractCwd(path: path)
            sessions.append(AgentSession(
                id: id, kind: kind,
                projectName: cwd.map { ($0 as NSString).lastPathComponent } ?? kind.rawValue,
                cwd: cwd ?? "",
                state: .waitingInput,
                metrics: kind == .claudeCode ? extractMetrics(path: path) : nil,
                lastActivity: mtime))
        }
        return sessions
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
