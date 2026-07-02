import Testing
import Foundation
@testable import AgentDockCore

private func tempDir() -> String {
    let dir = NSTemporaryDirectory() + "agentdock-test-\(UUID().uuidString.prefix(8))"
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}

@Suite struct ClaudeInstallerTests {
    private func makeInstaller(_ dir: String) -> ClaudeInstaller {
        ClaudeInstaller(settingsPath: dir + "/settings.json",
                        emitPath: "/usr/local/bin/agentdock-emit",
                        originalStatuslinePath: dir + "/original-statusline")
    }

    @Test func installIntoEmptySettings() throws {
        let dir = tempDir()
        let installer = makeInstaller(dir)
        #expect(!installer.isInstalled)
        try installer.install()
        #expect(installer.isInstalled)

        let json = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: dir + "/settings.json"))) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        #expect(hooks.count == 8)  // 7 个事件 hook + PermissionRequest 审批 hook
        let perm = (hooks["PermissionRequest"] as! [[String: Any]])[0]["hooks"] as! [[String: Any]]
        #expect((perm[0]["command"] as! String).contains("permission"))
        #expect(perm[0]["timeout"] as? Int == 55)
        let sl = json["statusLine"] as! [String: Any]
        #expect((sl["command"] as! String).contains("agentdock-emit"))
    }

    @Test func installPreservesExistingHooksAndStatusline() throws {
        let dir = tempDir()
        let existing = """
        {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"my-lint"}]}]},
         "statusLine":{"type":"command","command":"my-statusline.sh"},
         "model":"opus"}
        """
        try existing.write(toFile: dir + "/settings.json", atomically: true, encoding: .utf8)
        let installer = makeInstaller(dir)
        try installer.install()

        let json = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: dir + "/settings.json"))) as! [String: Any]
        let pre = (json["hooks"] as! [String: Any])["PreToolUse"] as! [[String: Any]]
        #expect(pre.count == 2)  // 用户原 hook + 我们的
        #expect(json["model"] as? String == "opus")
        // 原 statusline 命令被备份
        let backed = try String(contentsOfFile: dir + "/original-statusline", encoding: .utf8)
        #expect(backed == "my-statusline.sh")
        // 备份文件存在
        #expect(FileManager.default.fileExists(atPath: dir + "/settings.json.agentdock-backup"))
    }

    @Test func installIsIdempotent() throws {
        let dir = tempDir()
        let installer = makeInstaller(dir)
        try installer.install()
        try installer.install()
        let json = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: dir + "/settings.json"))) as! [String: Any]
        let pre = (json["hooks"] as! [String: Any])["PreToolUse"] as! [[String: Any]]
        #expect(pre.count == 1)
    }

    @Test func uninstallRestores() throws {
        let dir = tempDir()
        let existing = """
        {"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"my-lint"}]}]},
         "statusLine":{"type":"command","command":"my-statusline.sh"}}
        """
        try existing.write(toFile: dir + "/settings.json", atomically: true, encoding: .utf8)
        let installer = makeInstaller(dir)
        try installer.install()
        try installer.uninstall()
        #expect(!installer.isInstalled)

        let json = try JSONSerialization.jsonObject(
            with: Data(contentsOf: URL(fileURLWithPath: dir + "/settings.json"))) as! [String: Any]
        let pre = (json["hooks"] as! [String: Any])["PreToolUse"] as! [[String: Any]]
        #expect(pre.count == 1)  // 只剩用户原 hook
        let sl = json["statusLine"] as! [String: Any]
        #expect(sl["command"] as? String == "my-statusline.sh")
    }
}

@Suite struct CodexInstallerTests {
    @Test func installAppendsNotifyLine() throws {
        let dir = tempDir()
        try "model = \"gpt-5\"\n".write(toFile: dir + "/config.toml", atomically: true, encoding: .utf8)
        let installer = CodexInstaller(configPath: dir + "/config.toml", emitPath: "/x/agentdock-emit")
        try installer.install()
        #expect(installer.isInstalled)
        let text = try String(contentsOfFile: dir + "/config.toml", encoding: .utf8)
        #expect(text.contains("model = \"gpt-5\""))
        #expect(text.contains(#"notify = ["/x/agentdock-emit", "codex", "notify"]"#))
        // 幂等
        try installer.install()
        let after = try String(contentsOfFile: dir + "/config.toml", encoding: .utf8)
        #expect(after.components(separatedBy: "# agentdock").count == 2)
    }

    @Test func installRefusesWhenNotifyExists() throws {
        let dir = tempDir()
        try "notify = [\"other\"]\n".write(toFile: dir + "/config.toml", atomically: true, encoding: .utf8)
        let installer = CodexInstaller(configPath: dir + "/config.toml", emitPath: "/x/agentdock-emit")
        #expect(throws: (any Error).self) { try installer.install() }
    }

    @Test func uninstallRemovesOnlyOurLine() throws {
        let dir = tempDir()
        try "model = \"gpt-5\"\n".write(toFile: dir + "/config.toml", atomically: true, encoding: .utf8)
        let installer = CodexInstaller(configPath: dir + "/config.toml", emitPath: "/x/agentdock-emit")
        try installer.install()
        try installer.uninstall()
        let text = try String(contentsOfFile: dir + "/config.toml", encoding: .utf8)
        #expect(!text.contains("agentdock"))
        #expect(text.contains("model = \"gpt-5\""))
    }
}

@Suite struct CodexSessionTailerTests {
    @Test func tailsAppendedLines() async throws {
        let dir = tempDir()
        let file = dir + "/rollout-2026-07-02-abc.jsonl"
        try "old line\n".write(toFile: file, atomically: true, encoding: .utf8)

        let received = Mutex<[(String, String)]>([])
        let tailer = CodexSessionTailer(root: dir) { sid, line in
            received.withLock { $0.append((sid, String(decoding: line, as: UTF8.self))) }
        }
        tailer.start()
        defer { tailer.stop() }

        try await Task.sleep(for: .milliseconds(1200))
        let handle = FileHandle(forWritingAtPath: file)!
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("new line 1\nnew line 2\n".utf8))
        try handle.close()

        try await Task.sleep(for: .milliseconds(1500))
        let lines = received.withLock { $0 }
        #expect(lines.map(\.1) == ["new line 1", "new line 2"])  // 旧内容不重放
        #expect(lines.allSatisfy { $0.0 == "rollout-2026-07-02-abc" })
    }
}
