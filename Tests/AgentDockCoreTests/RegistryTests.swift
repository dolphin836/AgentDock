import Testing
import Foundation
import Darwin
@testable import AgentDockCore

@Suite struct ClaudeSessionRegistryTests {
    private func findDeadPid() -> Int {
        var pid: Int32 = 99999
        while kill(pid, 0) == 0 || errno == EPERM { pid -= 1 }
        return Int(pid)
    }

    @Test func filtersDeadSdkAndHiddenSessions() throws {
        let dir = NSTemporaryDirectory() + "agentdock-reg-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let alive = Int(getpid())
        let dead = findDeadPid()
        let entries: [[String: Any]] = [
            ["pid": alive, "sessionId": "s-user", "cwd": "/Users/eric/Work/x", "entrypoint": "cli"],
            ["pid": alive, "sessionId": "s-desktop", "cwd": "/Users/eric", "entrypoint": "claude-desktop"],
            ["pid": alive, "sessionId": "s-sdk", "cwd": "/Users/eric/Work/y", "entrypoint": "sdk-cli"],
            ["pid": alive, "sessionId": "s-hidden", "cwd": "/Users/eric/.claude-mem/obs", "entrypoint": "cli"],
            ["pid": dead, "sessionId": "s-dead", "cwd": "/Users/eric/Work/z", "entrypoint": "cli"],
        ]
        for (i, e) in entries.enumerated() {
            let data = try JSONSerialization.data(withJSONObject: e)
            try data.write(to: URL(fileURLWithPath: dir + "/\(i).json"))
        }
        let ids = ClaudeSessionRegistry(dir: dir).allowedSessionIds()
        #expect(ids == ["s-user", "s-desktop"])

        // entries 带注册进程 pid,供宿主 App 解析用
        let allowed = ClaudeSessionRegistry(dir: dir).allowedEntries()
        #expect(Set(allowed.map(\.sessionId)) == ["s-user", "s-desktop"])
        #expect(allowed.allSatisfy { $0.pid == Int32(alive) })
    }

    @Test func registryStatusMapsToSessionState() {
        func entry(_ status: String?, _ waitingFor: String? = nil) -> ClaudeSessionRegistry.Entry {
            ClaudeSessionRegistry.Entry(sessionId: "s", pid: 1, status: status, waitingFor: waitingFor)
        }
        #expect(entry("running").sessionState == .thinking)
        #expect(entry("idle").sessionState == .waitingInput)
        #expect(entry("waiting", "permission prompt").sessionState == .waitingApproval)
        #expect(entry("waiting").sessionState == .waitingInput)
        #expect(entry(nil).sessionState == nil)
        #expect(entry("unknown-future-status").sessionState == nil)
    }
}

@Suite struct HostAppResolverTests {
    @Test func readsProcessInfoOfSelf() {
        let pid = getpid()
        let exe = HostAppResolver.executablePath(of: pid)
        #expect(exe?.isEmpty == false)
        #expect(HostAppResolver.parentPid(of: pid) == getppid())
        let cwd = HostAppResolver.currentWorkingDirectory(of: pid)
        #expect(cwd?.hasPrefix("/") == true)
    }

    @Test func appPathWalksParentChainWithoutCrashing() {
        // 结果取决于测试运行环境(终端/IDE),只验证不崩溃且返回 .app 结尾或 nil
        let app = HostAppResolver.appPath(forPid: getpid())
        if let app { #expect(app.hasSuffix(".app")) }
    }
}

@MainActor
@Suite struct SessionStoreValidatorTests {
    @Test func rejectsUnregisteredClaudeSessions() {
        let store = SessionStore()
        store.claudeSessionValidator = { $0 == "registered" }
        store.apply(.event(AgentEvent(sessionId: "registered", kind: .claudeCode,
                                      cwd: "/x", name: "SessionStart")))
        store.apply(.event(AgentEvent(sessionId: "subagent", kind: .claudeCode,
                                      cwd: "/x", name: "SessionStart")))
        #expect(store.sessions.map(\.id) == ["registered"])

        // 回填同样过滤,且已存在的非法会话会被清除
        store.claudeSessionValidator = { _ in false }
        store.backfill([AgentSession(id: "ghost", kind: .claudeCode, projectName: "g",
                                     cwd: "/x", state: .waitingInput)])
        #expect(store.sessions.isEmpty)
    }
}
