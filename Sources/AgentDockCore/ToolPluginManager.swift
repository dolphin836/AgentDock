import Foundation
import AppKit

// [skill: dev-dna] 按用户偏好：CLI 封装集中、错误带上下文、UI 只消费 Result

/// 工具页可执行的管理动作（按 agent 能力分层）
public enum ToolManageAction: String, Sendable, CaseIterable {
    case checkUpdate
    case update
    case uninstall
    case openInHost
}

/// 单次管理操作结果文案（已本地化由 UI 层处理时可直接展示英文/中性句）
public struct ToolManageResult: Sendable {
    public let ok: Bool
    public let message: String
    /// 检测更新时：若有新版本则填最新版本号
    public let latestVersion: String?

    public init(ok: Bool, message: String, latestVersion: String? = nil) {
        self.ok = ok
        self.message = message
        self.latestVersion = latestVersion
    }
}

/// 调用本机 `claude` / `codex` CLI，或删除 Skill 目录；Cursor 仅打开宿主 App。
public enum ToolPluginManager {

    /// 该条目支持哪些动作
    public static func actions(for item: ToolInventoryItem) -> [ToolManageAction] {
        switch (item.agent, item.kind) {
        case (.claudeCode, .plugin):
            return [.checkUpdate, .update, .uninstall]
        case (.codex, .plugin):
            return [.checkUpdate, .update, .uninstall]
        case (.cursor, .plugin), (.cursor, .mcp):
            return [.openInHost]
        case (_, .skill):
            return [.uninstall]
        case (.claudeCode, .mcp), (.codex, .mcp):
            // MCP 改配置风险高，本版不做
            return []
        }
    }

    public static func perform(_ action: ToolManageAction,
                               item: ToolInventoryItem) async -> ToolManageResult {
        switch action {
        case .checkUpdate:
            return await checkUpdate(item)
        case .update:
            return await update(item)
        case .uninstall:
            return await uninstall(item)
        case .openInHost:
            return openInHost(item)
        }
    }

    // MARK: - check

    private static func checkUpdate(_ item: ToolInventoryItem) async -> ToolManageResult {
        switch item.agent {
        case .claudeCode:
            return await checkClaude(item)
        case .codex:
            return await checkCodex(item)
        default:
            return ToolManageResult(ok: false, message: "Check update is not supported for this item")
        }
    }

    private static func checkClaude(_ item: ToolInventoryItem) async -> ToolManageResult {
        let id = pluginSelector(item)
        let market = marketplace(from: id)
        if let market {
            _ = try? await run(cli: .claude, ["plugin", "marketplace", "update", market])
        }
        let before = item.version
        guard let listed = try? await claudeInstalled() else {
            return ToolManageResult(ok: false, message: "Failed to list Claude plugins")
        }
        let current = listed.first { $0.id == id }?.version ?? before
        // Claude available 列表通常不带 version；刷新 marketplace 后提示用户点更新
        if let current, !current.isEmpty {
            return ToolManageResult(
                ok: true,
                message: "Marketplace refreshed · current v\(current) · tap Update for latest",
                latestVersion: nil)
        }
        return ToolManageResult(ok: true,
                                message: "Marketplace refreshed · tap Update for latest")
    }

    private static func checkCodex(_ item: ToolInventoryItem) async -> ToolManageResult {
        let id = pluginSelector(item)
        let market = marketplace(from: id)
        if let market {
            _ = try? await run(cli: .codex, ["plugin", "marketplace", "upgrade", market, "--json"])
        } else {
            _ = try? await run(cli: .codex, ["plugin", "marketplace", "upgrade", "--json"])
        }
        guard let dump = try? await codexList(available: true) else {
            return ToolManageResult(ok: false, message: "Failed to list Codex plugins")
        }
        let installed = dump.installed.first { $0.pluginId == id }
        let available = dump.available.first { $0.pluginId == id }
        let cur = installed?.version ?? item.version
        let latest = available?.version
        if let cur, let latest, cur != latest {
            return ToolManageResult(
                ok: true,
                message: "Update available · v\(cur) → v\(latest)",
                latestVersion: latest)
        }
        if let cur {
            return ToolManageResult(ok: true, message: "Up to date · v\(cur)", latestVersion: nil)
        }
        return ToolManageResult(ok: true, message: "No version info from Codex")
    }

    // MARK: - update

    private static func update(_ item: ToolInventoryItem) async -> ToolManageResult {
        let id = pluginSelector(item)
        switch item.agent {
        case .claudeCode:
            do {
                let out = try await run(cli: .claude, ["plugin", "update", id])
                let listed = try? await claudeInstalled()
                let ver = listed?.first { $0.id == id }?.version
                let msg = ver.map { "Updated · v\($0)" } ?? (out.stdout.isEmpty ? "Updated" : out.stdout)
                return ToolManageResult(ok: out.exitCode == 0, message: trim(msg),
                                        latestVersion: ver)
            } catch {
                return ToolManageResult(ok: false, message: error.localizedDescription)
            }
        case .codex:
            do {
                if let market = marketplace(from: id) {
                    _ = try await run(cli: .codex, ["plugin", "marketplace", "upgrade", market, "--json"])
                }
                // 重新 add 以对齐 snapshot 最新版
                let out = try await run(cli: .codex, ["plugin", "add", id, "--json"])
                let dump = try? await codexList(available: false)
                let ver = dump?.installed.first { $0.pluginId == id }?.version
                if out.exitCode == 0 {
                    return ToolManageResult(ok: true,
                                            message: ver.map { "Updated · v\($0)" } ?? "Updated",
                                            latestVersion: ver)
                }
                return ToolManageResult(ok: false, message: trim(out.stderr.isEmpty ? out.stdout : out.stderr))
            } catch {
                return ToolManageResult(ok: false, message: error.localizedDescription)
            }
        default:
            return ToolManageResult(ok: false, message: "Update is not supported for this item")
        }
    }

    // MARK: - uninstall

    private static func uninstall(_ item: ToolInventoryItem) async -> ToolManageResult {
        switch (item.agent, item.kind) {
        case (.claudeCode, .plugin):
            do {
                let out = try await run(cli: .claude,
                                        ["plugin", "uninstall", pluginSelector(item), "-y"])
                return ToolManageResult(ok: out.exitCode == 0,
                                        message: out.exitCode == 0 ? "Uninstalled" : trim(out.stderr))
            } catch {
                return ToolManageResult(ok: false, message: error.localizedDescription)
            }
        case (.codex, .plugin):
            do {
                let out = try await run(cli: .codex,
                                        ["plugin", "remove", pluginSelector(item), "--json"])
                return ToolManageResult(ok: out.exitCode == 0,
                                        message: out.exitCode == 0 ? "Uninstalled" : trim(out.stderr))
            } catch {
                return ToolManageResult(ok: false, message: error.localizedDescription)
            }
        case (_, .skill):
            guard let path = item.path, !path.isEmpty else {
                return ToolManageResult(ok: false, message: "Skill path missing")
            }
            // 只允许删 skills 目录下的条目，避免误删
            let allowed = ["/skills/", "/.agents/skills/", "/skills-cursor/"]
            guard allowed.contains(where: { path.contains($0) }) else {
                return ToolManageResult(ok: false, message: "Refusing to delete path outside skills dirs")
            }
            do {
                try FileManager.default.removeItem(atPath: path)
                return ToolManageResult(ok: true, message: "Uninstalled")
            } catch {
                return ToolManageResult(ok: false, message: error.localizedDescription)
            }
        default:
            return ToolManageResult(ok: false, message: "Uninstall is not supported for this item")
        }
    }

    private static func openInHost(_ item: ToolInventoryItem) -> ToolManageResult {
        let candidates = [
            "/Applications/Cursor.app",
            NSHomeDirectory() + "/Applications/Cursor.app",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            return ToolManageResult(ok: true, message: "Opened Cursor — manage plugins in Customize")
        }
        return ToolManageResult(ok: false, message: "Cursor.app not found")
    }

    // MARK: - CLI helpers

    private enum CLI {
        case claude, codex
        var name: String {
            switch self {
            case .claude: "claude"
            case .codex: "codex"
            }
        }
    }

    private struct RunOutput {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private static func run(cli: CLI, _ args: [String]) async throws -> RunOutput {
        let path = try resolveBinary(cli.name)
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: path)
                    proc.arguments = args
                    let out = Pipe()
                    let err = Pipe()
                    proc.standardOutput = out
                    proc.standardError = err
                    // 非交互
                    var env = ProcessInfo.processInfo.environment
                    env["TERM"] = "dumb"
                    env["NO_COLOR"] = "1"
                    proc.environment = env
                    try proc.run()
                    proc.waitUntilExit()
                    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(),
                                        encoding: .utf8) ?? ""
                    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                                        encoding: .utf8) ?? ""
                    cont.resume(returning: RunOutput(exitCode: proc.terminationStatus,
                                                     stdout: stdout, stderr: stderr))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private static func resolveBinary(_ name: String) throws -> String {
        let candidates = [
            NSHomeDirectory() + "/.local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // PATH which
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = [name]
        let pipe = Pipe()
        which.standardOutput = pipe
        try which.run()
        which.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty,
           FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        throw NSError(domain: "ToolPluginManager", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "\(name) CLI not found"])
    }

    private static func pluginSelector(_ item: ToolInventoryItem) -> String {
        // inventory 里插件 name 已是 plugin@marketplace
        item.name
    }

    private static func marketplace(from selector: String) -> String? {
        guard let at = selector.firstIndex(of: "@") else { return nil }
        return String(selector[selector.index(after: at)...])
    }

    private static func trim(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 160 { return String(t.prefix(157)) + "…" }
        return t.isEmpty ? "Done" : t
    }

    // MARK: - JSON parse

    private struct ClaudePlugin: Decodable {
        let id: String
        let version: String?
    }

    private struct CodexPlugin: Decodable {
        let pluginId: String
        let version: String?
    }

    private struct CodexList: Decodable {
        let installed: [CodexPlugin]
        let available: [CodexPlugin]
        init(installed: [CodexPlugin], available: [CodexPlugin] = []) {
            self.installed = installed
            self.available = available
        }
    }

    private static func claudeInstalled() async throws -> [ClaudePlugin] {
        let out = try await run(cli: .claude, ["plugin", "list", "--json"])
        guard out.exitCode == 0,
              let data = out.stdout.data(using: .utf8) else {
            throw NSError(domain: "ToolPluginManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "claude plugin list failed"])
        }
        // list --json 无 --available 时是数组
        if let arr = try? JSONDecoder().decode([ClaudePlugin].self, from: data) {
            return arr
        }
        struct Wrap: Decodable { let installed: [ClaudePlugin] }
        return try JSONDecoder().decode(Wrap.self, from: data).installed
    }

    private static func codexList(available: Bool) async throws -> CodexList {
        var args = ["plugin", "list", "--json"]
        if available { args.append("--available") }
        let out = try await run(cli: .codex, args)
        guard out.exitCode == 0,
              let data = out.stdout.data(using: .utf8) else {
            throw NSError(domain: "ToolPluginManager", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "codex plugin list failed"])
        }
        struct Wrap: Decodable {
            let installed: [CodexPlugin]
            let available: [CodexPlugin]?
        }
        let w = try JSONDecoder().decode(Wrap.self, from: data)
        return CodexList(installed: w.installed, available: w.available ?? [])
    }
}
