import Foundation

/// 监控目录树下的 JSONL 会话文件,对新增行回调(秒级轮询)。
/// Codex 用于 ~/.codex/sessions 的 rollout;Cursor 用于 ~/.cursor/projects 的
/// agent transcript——后者是 hooks 之外的实时兜底通道。
/// sessionId 取文件名中的线程 uuid;解析失败的行由上层 ignored。
public final class CodexSessionTailer: @unchecked Sendable {
    private let root: String
    private let pathFilter: @Sendable (String) -> Bool
    private let onLine: @Sendable (_ path: String, _ sessionId: String, _ line: Data) -> Void
    private let queue = DispatchQueue(label: "agentdock.session-tailer")
    private var timer: DispatchSourceTimer?
    private var offsets: [String: UInt64] = [:]  // path -> 已读偏移
    private var started = false

    public init(root: String,
                pathFilter: @escaping @Sendable (String) -> Bool = { _ in true },
                onLine: @escaping @Sendable (_ path: String, _ sessionId: String, _ line: Data) -> Void) {
        self.root = root
        self.pathFilter = pathFilter
        self.onLine = onLine
    }

    public func start() {
        queue.sync {
            guard !started else { return }
            started = true
            // 首次扫描:已存在文件从末尾开始,只报告增量
            for path in jsonlFiles() {
                offsets[path] = fileSize(path)
            }
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + 1, repeating: 1.0)
            t.setEventHandler { [weak self] in self?.poll() }
            t.resume()
            timer = t
        }
    }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            started = false
        }
    }

    private func poll() {
        for path in jsonlFiles() {
            let size = fileSize(path)
            let offset = offsets[path] ?? 0
            guard size > offset else {
                if size < offset { offsets[path] = size }  // 文件被截断,重置
                continue
            }
            guard let handle = FileHandle(forReadingAtPath: path) else { continue }
            defer { try? handle.close() }
            try? handle.seek(toOffset: offset)
            guard let data = try? handle.readToEnd(), !data.isEmpty else { continue }
            offsets[path] = offset + UInt64(data.count)
            let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            let sessionId = SessionBackfillScanner.codexThreadId(fromRolloutName: name)
            for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
                onLine(path, sessionId, Data(line))
            }
        }
    }

    private func jsonlFiles() -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [] }
        return enumerator.compactMap { item in
            guard let rel = item as? String, rel.hasSuffix(".jsonl") else { return nil }
            let path = (root as NSString).appendingPathComponent(rel)
            return pathFilter(path) ? path : nil
        }
    }

    private func fileSize(_ path: String) -> UInt64 {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? UInt64) ?? 0
    }
}
