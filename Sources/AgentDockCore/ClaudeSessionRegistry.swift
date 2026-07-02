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

    /// 允许展示的会话 id:有注册记录 + 进程还活着 + 非 SDK 工具会话 + 非隐藏目录
    public func allowedSessionIds() -> Set<String> {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        var ids: Set<String> = []
        for name in names where name.hasSuffix(".json") {
            let path = (dir as NSString).appendingPathComponent(name)
            guard let data = FileManager.default.contents(atPath: path),
                  let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let sessionId = obj["sessionId"] as? String
            else { continue }
            if let entrypoint = obj["entrypoint"] as? String, entrypoint == "sdk-cli" { continue }
            if let cwd = obj["cwd"] as? String, SessionBackfillScanner.isHiddenPath(cwd) { continue }
            if let pid = obj["pid"] as? Int, !Self.isProcessAlive(Int32(pid)) { continue }
            ids.insert(sessionId)
        }
        return ids
    }

    public static func isProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}
