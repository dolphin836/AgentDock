import Foundation
import Darwin

/// ~/.claude/sessions/<pid>.json 是用户会话的注册表(CLI/桌面端/IDE 插件都会注册);
/// 后台子 agent(Task/Agent 工具派生)不注册,SDK 起的工具会话 entrypoint 为 "sdk-cli"。
/// 以它为准过滤,才能只展示用户亲手开的会话。
public struct ClaudeSessionRegistry: Sendable {
    public let dir: String

    public init(dir: String) {
        self.dir = dir
    }

    public struct Entry: Sendable {
        public let sessionId: String
        public let pid: Int32
        /// 注册表实时状态("running"/"idle"/"waiting"),hooks 不可用时的次级状态源
        public let status: String?
        /// status=waiting 时在等什么(如 "permission prompt")
        public let waitingFor: String?

        /// 注册表状态 → 统一状态;识别不了返回 nil(维持既有推断)
        public var sessionState: SessionState? {
            switch status {
            case "running": .thinking
            case "idle": .waitingInput
            case "waiting":
                waitingFor?.lowercased().contains("permission") == true
                    ? .waitingApproval : .waitingInput
            default: nil
            }
        }
    }

    /// 允许展示的会话 id:有注册记录 + 进程还活着 + 非 SDK 工具会话 + 非隐藏目录
    public func allowedSessionIds() -> Set<String> {
        Set(allowedEntries().map(\.sessionId))
    }

    /// 同 allowedSessionIds,但带注册进程 pid(用于沿父进程链解析宿主 App)
    public func allowedEntries() -> [Entry] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        var entries: [Entry] = []
        for name in names where name.hasSuffix(".json") {
            let path = (dir as NSString).appendingPathComponent(name)
            guard let data = FileManager.default.contents(atPath: path),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let sessionId = obj["sessionId"] as? String,
                  let pid = obj["pid"] as? Int
            else { continue }
            if let entrypoint = obj["entrypoint"] as? String, entrypoint == "sdk-cli" { continue }
            if let cwd = obj["cwd"] as? String, SessionBackfillScanner.isHiddenPath(cwd) { continue }
            guard Self.isProcessAlive(Int32(pid)) else { continue }
            entries.append(Entry(sessionId: sessionId, pid: Int32(pid),
                                 status: obj["status"] as? String,
                                 waitingFor: obj["waitingFor"] as? String))
        }
        return entries
    }

    public static func isProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}
