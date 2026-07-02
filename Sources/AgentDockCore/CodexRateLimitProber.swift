import Foundation

/// 通过 `codex app-server` 的 JSON-RPC 查询账号限额(account/rateLimits/read)。
/// 阻塞式,调用方应放到后台线程;失败一律返回 nil。
public enum CodexRateLimitProber {
    public static let binaryCandidates = [
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex",
        NSHomeDirectory() + "/.local/bin/codex",
    ]

    public static func findBinary() -> String? {
        binaryCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func fetch(binary: String? = nil, timeout: TimeInterval = 8) -> RateLimits? {
        guard let bin = binary ?? findBinary() else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.arguments = ["app-server"]
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        defer {
            if process.isRunning { process.terminate() }
        }

        func send(_ json: String) {
            stdin.fileHandleForWriting.write(Data((json + "\n").utf8))
        }
        send(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"agentdock","title":"AgentDock","version":"0.1.0"}}}"#)
        send(#"{"jsonrpc":"2.0","method":"initialized"}"#)
        Thread.sleep(forTimeInterval: 0.8)  // handshake 后需等片刻,否则返回空
        send(#"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}"#)

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()
        let handle = stdout.fileHandleForReading
        while Date() < deadline {
            let chunk = handle.availableData
            if chunk.isEmpty {
                Thread.sleep(forTimeInterval: 0.1)
                continue
            }
            buffer.append(chunk)
            for line in buffer.split(separator: UInt8(ascii: "\n")) {
                if let limits = parseResponse(Data(line)) { return limits }
            }
        }
        return nil
    }

    /// 解析 id=2 的响应:result 里 primary(5h)/secondary(weekly)的 usedPercent
    static func parseResponse(_ line: Data) -> RateLimits? {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              obj["id"] as? Int == 2,
              let result = obj["result"] as? [String: Any]
        else { return nil }
        // 字段可能在 result 顶层或 result.rateLimits 下,取存在的那层
        let container = (result["rateLimits"] as? [String: Any]) ?? result
        var limits = RateLimits()
        if let p = container["primary"] as? [String: Any] {
            limits.fiveHourPct = intValue(p["usedPercent"])
        }
        if let s = container["secondary"] as? [String: Any] {
            limits.sevenDayPct = intValue(s["usedPercent"])
        }
        return (limits.fiveHourPct != nil || limits.sevenDayPct != nil) ? limits : nil
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        return nil
    }
}
