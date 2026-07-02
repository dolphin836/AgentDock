import Foundation

/// 监控 ~/.codex/sessions 目录树,对每个 rollout JSONL 文件的新增行回调。
/// sessionId 取文件名(去扩展名);解析失败的行由上层 ignored。
public final class CodexSessionTailer: @unchecked Sendable {
    private let root: String
    private let onLine: @Sendable (_ sessionId: String, _ line: Data) -> Void
    private let queue = DispatchQueue(label: "agentdock.codex-tailer")
    private var timer: DispatchSourceTimer?
    private var offsets: [String: UInt64] = [:]  // path -> 已读偏移
    private var started = false

    public init(root: String, onLine: @escaping @Sendable (_ sessionId: String, _ line: Data) -> Void) {
        self.root = root
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
            let sessionId = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            for line in data.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
                onLine(sessionId, Data(line))
            }
        }
    }

    private func jsonlFiles() -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: root) else { return [] }
        return enumerator.compactMap { item in
            guard let rel = item as? String, rel.hasSuffix(".jsonl") else { return nil }
            return (root as NSString).appendingPathComponent(rel)
        }
    }

    private func fileSize(_ path: String) -> UInt64 {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64) ?? 0 ?? 0
    }
}
