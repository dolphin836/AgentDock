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
        // 全部事件 hook + PermissionRequest 审批 hook
        #expect(hooks.count == ClaudeInstaller.hookEvents.count + 1)
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

    @Test func installChainsWhenNotifyExists() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "notify = [\"/Apps/Other Notifier\", \"turn-ended\"]\nmodel = \"gpt-5\"\n"
            .write(toFile: dir + "/config.toml", atomically: true, encoding: .utf8)
        let installer = CodexInstaller(configPath: dir + "/config.toml",
                                       emitPath: dir + "/agentdock-emit")
        try installer.install()
        #expect(installer.isInstalled)

        let text = try String(contentsOfFile: dir + "/config.toml", encoding: .utf8)
        // 原 notify 被注释保存,新 notify 指向链式脚本
        #expect(text.contains("# notify = [\"/Apps/Other Notifier\", \"turn-ended\"] # agentdock-preserved"))
        #expect(text.contains(#"notify = ["\#(dir)/codex-notify-chain"] # agentdock"#))
        // 链式脚本先转发原程序,再发 AgentDock
        let script = try String(contentsOfFile: installer.chainScriptPath, encoding: .utf8)
        #expect(script.contains("'/Apps/Other Notifier' 'turn-ended' \"$@\""))
        #expect(script.contains("agentdock-emit\" codex notify"))

        // 卸载:还原原 notify 行,删除链式脚本
        try installer.uninstall()
        let restored = try String(contentsOfFile: dir + "/config.toml", encoding: .utf8)
        #expect(restored.contains("notify = [\"/Apps/Other Notifier\", \"turn-ended\"]"))
        #expect(!restored.contains("agentdock"))
        #expect(!FileManager.default.fileExists(atPath: installer.chainScriptPath))
    }

    @Test func parseNotifyArgs() {
        #expect(CodexInstaller.parseNotifyArgs(#"notify = ["/a b/c", "x"]"#) == ["/a b/c", "x"])
        #expect(CodexInstaller.parseNotifyArgs(#"notify = []"#) == nil)
        #expect(CodexInstaller.parseNotifyArgs("nonsense") == nil)
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

@Suite struct CursorInstallerTests {
    private func makeInstaller() -> (CursorInstaller, String) {
        let dir = tempDir()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/hooks.json"
        return (CursorInstaller(hooksPath: path, emitPath: "/x/agentdock-emit"), path)
    }

    @Test func installIntoMissingFile() throws {
        let (installer, path) = makeInstaller()
        try installer.install()
        #expect(installer.isInstalled)
        let obj = try JSONSerialization.jsonObject(
            with: FileManager.default.contents(atPath: path)!) as! [String: Any]
        #expect(obj["version"] as? Int == 1)
        let hooks = obj["hooks"] as! [String: Any]
        for event in CursorInstaller.hookEvents {
            let entries = hooks[event] as! [[String: Any]]
            #expect(entries.contains { ($0["command"] as! String).contains("agentdock-emit") })
        }
    }

    @Test func installsShellAndMCPHookEvents() throws {
        let (installer, path) = makeInstaller()
        try installer.install()
        let obj = try JSONSerialization.jsonObject(
            with: FileManager.default.contents(atPath: path)!) as! [String: Any]
        let hooks = obj["hooks"] as! [String: Any]
        // 补齐 shell/MCP/失败 hook,才能在 hooks 修好的版本上拿到完整工具态
        for event in ["beforeShellExecution", "afterShellExecution",
                      "beforeMCPExecution", "afterMCPExecution", "postToolUseFailure",
                      "subagentStart", "subagentStop"] {
            #expect(hooks[event] != nil, "missing hook: \(event)")
            let entries = hooks[event] as! [[String: Any]]
            #expect(entries.contains { ($0["command"] as! String).contains("agentdock-emit") })
        }
        // 卸载后新事件也应被清干净
        try installer.uninstall()
        let after = try JSONSerialization.jsonObject(
            with: FileManager.default.contents(atPath: path)!) as! [String: Any]
        let afterHooks = after["hooks"] as! [String: Any]
        #expect(afterHooks["beforeShellExecution"] == nil)
        #expect(afterHooks["afterMCPExecution"] == nil)
        #expect(afterHooks["subagentStart"] == nil)
        #expect(afterHooks["subagentStop"] == nil)
    }

    @Test func installPreservesUserHooksAndIsIdempotent() throws {
        let (installer, path) = makeInstaller()
        let existing = #"{"version":1,"hooks":{"preToolUse":[{"command":"my-hook.sh"}]}}"#
        try existing.write(toFile: path, atomically: true, encoding: .utf8)

        try installer.install()
        try installer.install()  // 幂等

        let obj = try JSONSerialization.jsonObject(
            with: FileManager.default.contents(atPath: path)!) as! [String: Any]
        let pre = (obj["hooks"] as! [String: Any])["preToolUse"] as! [[String: Any]]
        #expect(pre.count == 2)  // 用户的 + 我们的,不重复追加
        #expect(pre.contains { $0["command"] as? String == "my-hook.sh" })

        try installer.uninstall()
        #expect(!installer.isInstalled)
        let after = try JSONSerialization.jsonObject(
            with: FileManager.default.contents(atPath: path)!) as! [String: Any]
        let afterPre = (after["hooks"] as! [String: Any])["preToolUse"] as! [[String: Any]]
        #expect(afterPre.map { $0["command"] as? String } == ["my-hook.sh"])
        #expect((after["hooks"] as! [String: Any])["stop"] == nil)
    }
}

@Suite struct CodexSessionTailerTests {
    @Test func tailsAppendedLines() async throws {
        let dir = tempDir()
        let file = dir + "/rollout-2026-07-02T10-00-00-abc.jsonl"
        try "old line\n".write(toFile: file, atomically: true, encoding: .utf8)

        let received = Mutex<[(String, String)]>([])
        let tailer = CodexSessionTailer(root: dir) { _, sid, line in
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
        #expect(lines.allSatisfy { $0.0 == "abc" })  // sessionId 是文件名中的线程 id
    }
}
