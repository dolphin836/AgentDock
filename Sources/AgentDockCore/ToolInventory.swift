import Foundation

// [skill: dev-dna] 按用户偏好：纯磁盘扫描 + 稳定 id，UI 只消费快照

/// 已安装扩展的类别（插件 / Skill / MCP）
public enum ToolItemKind: String, Sendable, CaseIterable {
    case plugin
    case skill
    case mcp
}

/// 单个已安装扩展条目
public struct ToolInventoryItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: ToolItemKind
    public let agent: AgentKind
    public let name: String
    /// 短展示名（去 plugin- 前缀等）
    public let displayName: String
    public let version: String?
    public let path: String?
    /// 文件/安装目录 mtime，作「安装或更新」近似
    public let modifiedAt: Date?

    public init(id: String, kind: ToolItemKind, agent: AgentKind, name: String,
                displayName: String? = nil, version: String? = nil,
                path: String? = nil, modifiedAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.agent = agent
        self.name = name
        self.displayName = displayName ?? name
        self.version = version
        self.path = path
        self.modifiedAt = modifiedAt
    }
}

/// 某一 agent 的库存汇总
public struct ToolInventoryGroup: Identifiable, Sendable, Equatable {
    public var id: AgentKind { agent }
    public let agent: AgentKind
    public let items: [ToolInventoryItem]

    public var pluginCount: Int { items.filter { $0.kind == .plugin }.count }
    public var skillCount: Int { items.filter { $0.kind == .skill }.count }
    public var mcpCount: Int { items.filter { $0.kind == .mcp }.count }

    public init(agent: AgentKind, items: [ToolInventoryItem]) {
        self.agent = agent
        self.items = items.sorted {
            if $0.kind != $1.kind {
                return Self.kindOrder($0.kind) < Self.kindOrder($1.kind)
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private static func kindOrder(_ k: ToolItemKind) -> Int {
        switch k {
        case .plugin: 0
        case .mcp: 1
        case .skill: 2
        }
    }
}

/// 某工具的调用统计（来自 HistoryStore.tool_call）
public struct ToolUsageStat: Sendable, Equatable {
    public let toolKey: String
    public let callCount: Int
    public let lastUsedAt: Date?
    /// 已闭合调用的累计时长（秒）；未闭合的不计
    public let totalDurationSeconds: Double

    public init(toolKey: String, callCount: Int, lastUsedAt: Date?,
                totalDurationSeconds: Double = 0) {
        self.toolKey = toolKey
        self.callCount = callCount
        self.lastUsedAt = lastUsedAt
        self.totalDurationSeconds = totalDurationSeconds
    }
}

/// 工具调用阶段（开始 / 结束，用于统计次数与时长）
public enum ToolCallPhase: Sendable {
    case begin, end
}

/// 扫描本机 Claude / Codex / Cursor 已安装的插件、Skill、MCP
public enum ToolInventoryScanner {
    public static func scan(home: String = NSHomeDirectory()) -> [ToolInventoryGroup] {
        let groups: [ToolInventoryGroup] = [
            ToolInventoryGroup(agent: .claudeCode, items: scanClaude(home: home)),
            ToolInventoryGroup(agent: .codex, items: scanCodex(home: home)),
            ToolInventoryGroup(agent: .cursor, items: scanCursor(home: home)),
        ]
        return groups.filter { !$0.items.isEmpty }
    }

    // MARK: - Claude

    private static func scanClaude(home: String) -> [ToolInventoryItem] {
        var items: [ToolInventoryItem] = []
        let pluginsJSON = home + "/.claude/plugins/installed_plugins.json"
        if let data = FileManager.default.contents(atPath: pluginsJSON),
           let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let plugins = root["plugins"] as? [String: Any] {
            for (name, entries) in plugins {
                let entry = (entries as? [[String: Any]])?.first
                let path = entry?["installPath"] as? String
                let version = entry?["version"] as? String
                items.append(ToolInventoryItem(
                    id: "claude-plugin:\(name)",
                    kind: .plugin,
                    agent: .claudeCode,
                    name: name,
                    displayName: shortPluginName(name),
                    version: version,
                    path: path,
                    modifiedAt: mtime(path) ?? mtime(pluginsJSON)))
            }
        }

        items += skillDirs(at: home + "/.claude/skills", agent: .claudeCode, prefix: "claude-skill")
        // 用户级 agents skills（部分 skill 以 symlink 形式挂进来）
        items += skillDirs(at: home + "/.agents/skills", agent: .claudeCode, prefix: "claude-agents-skill")

        items += mcpServers(
            fromJSONFiles: [home + "/.claude.json", home + "/.claude/settings.json"],
            agent: .claudeCode,
            idPrefix: "claude-mcp")
        return dedupe(items)
    }

    // MARK: - Codex

    private static func scanCodex(home: String) -> [ToolInventoryItem] {
        var items: [ToolInventoryItem] = []
        let configPath = home + "/.codex/config.toml"
        if let text = try? String(contentsOfFile: configPath, encoding: .utf8) {
            for name in tomlTableNames(text, prefix: "plugins.") {
                let enabled = tomlBool(text, table: "plugins.\"\(name)\"", key: "enabled") ?? true
                guard enabled else { continue }
                let resolved = resolveCodexPlugin(home: home, name: name)
                items.append(ToolInventoryItem(
                    id: "codex-plugin:\(name)",
                    kind: .plugin,
                    agent: .codex,
                    name: name,
                    displayName: shortPluginName(name),
                    version: resolved.version,
                    path: resolved.path ?? configPath,
                    modifiedAt: mtime(resolved.path) ?? mtime(configPath)))
            }
            for name in tomlTableNames(text, prefix: "mcp_servers.") {
                // 跳过 env 子表
                if name.contains(".") { continue }
                let enabled = tomlBool(text, table: "mcp_servers.\(name)", key: "enabled") ?? true
                guard enabled else { continue }
                items.append(ToolInventoryItem(
                    id: "codex-mcp:\(name)",
                    kind: .mcp,
                    agent: .codex,
                    name: name,
                    displayName: ThirdPartyToolDisplay.shortenServer(name),
                    path: configPath,
                    modifiedAt: mtime(configPath)))
            }
        }
        items += skillDirs(at: home + "/.codex/skills", agent: .codex, prefix: "codex-skill")
        return dedupe(items)
    }

    // MARK: - Cursor

    private static func scanCursor(home: String) -> [ToolInventoryItem] {
        var items: [ToolInventoryItem] = []
        let cacheRoot = home + "/.cursor/plugins/cache"
        if let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: cacheRoot),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                guard url.lastPathComponent == "plugin.json",
                      url.path.contains("/.cursor-plugin/") || url.path.hasSuffix("/.cursor-plugin/plugin.json")
                        || url.deletingLastPathComponent().lastPathComponent == ".cursor-plugin"
                else { continue }
                guard let data = try? Data(contentsOf: url),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let name = json["name"] as? String
                else { continue }
                let version = json["version"] as? String
                let pluginRoot = url.deletingLastPathComponent().deletingLastPathComponent().path
                items.append(ToolInventoryItem(
                    id: "cursor-plugin:\(name)",
                    kind: .plugin,
                    agent: .cursor,
                    name: name,
                    displayName: shortPluginName(name),
                    version: version,
                    path: pluginRoot,
                    modifiedAt: mtime(pluginRoot) ?? mtime(url.path)))
                // 插件自带 MCP
                let mcpPath = (pluginRoot as NSString).appendingPathComponent("mcp.json")
                if let mcpData = FileManager.default.contents(atPath: mcpPath),
                   let mcpJSON = try? JSONSerialization.jsonObject(with: mcpData) as? [String: Any],
                   let servers = mcpJSON["mcpServers"] as? [String: Any] {
                    for serverName in servers.keys {
                        items.append(ToolInventoryItem(
                            id: "cursor-mcp:\(name)/\(serverName)",
                            kind: .mcp,
                            agent: .cursor,
                            name: serverName,
                            displayName: ThirdPartyToolDisplay.shortenServer(serverName),
                            path: mcpPath,
                            modifiedAt: mtime(mcpPath)))
                    }
                }
            }
        }

        items += skillDirs(at: home + "/.cursor/skills-cursor", agent: .cursor, prefix: "cursor-skill")
        items += skillDirs(at: home + "/.cursor/skills", agent: .cursor, prefix: "cursor-user-skill")
        items += mcpServers(
            fromJSONFiles: [home + "/.cursor/mcp.json"],
            agent: .cursor,
            idPrefix: "cursor-mcp")
        return dedupe(items)
    }

    // MARK: - helpers

    private static func skillDirs(at root: String, agent: AgentKind, prefix: String) -> [ToolInventoryItem] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: root) else { return [] }
        return names.compactMap { name -> ToolInventoryItem? in
            if name.hasPrefix(".") { return nil }
            let path = (root as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
            // 需要有 SKILL.md 才算 skill（避免误扫缓存目录）
            let skillMD = (path as NSString).appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD) else { return nil }
            let version = skillVersion(from: skillMD)
            return ToolInventoryItem(
                id: "\(prefix):\(name)",
                kind: .skill,
                agent: agent,
                name: name,
                displayName: name,
                version: version,
                path: path,
                modifiedAt: mtime(skillMD) ?? mtime(path))
        }
    }

    /// 从 SKILL.md frontmatter 读 version（没有则 nil）
    private static func skillVersion(from path: String) -> String? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8),
              text.hasPrefix("---") else { return nil }
        let parts = text.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        for line in parts[1].split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.lowercased().hasPrefix("version:") else { continue }
            var v = String(t.dropFirst("version:".count)).trimmingCharacters(in: .whitespaces)
            if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                v = String(v.dropFirst().dropLast())
            }
            return v.isEmpty ? nil : v
        }
        return nil
    }

    /// Codex 插件名 `browser@openai-bundled` → cache 目录里的 version + path
    private static func resolveCodexPlugin(home: String, name: String) -> (version: String?, path: String?) {
        let parts = name.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return (nil, nil) }
        let plugin = parts[0], market = parts[1]
        let root = "\(home)/.codex/plugins/cache/\(market)/\(plugin)"
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: root) else {
            return (nil, nil)
        }
        // 版本目录名即版本号；取字典序最大的近似最新
        let latest = versions.filter { !$0.hasPrefix(".") }.sorted().last
        guard let latest else { return (nil, root) }
        let path = (root as NSString).appendingPathComponent(latest)
        let manifest = path + "/.codex-plugin/plugin.json"
        if let data = FileManager.default.contents(atPath: manifest),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let v = json["version"] as? String {
            return (v, path)
        }
        return (latest, path)
    }

    private static func mcpServers(fromJSONFiles paths: [String], agent: AgentKind,
                                   idPrefix: String) -> [ToolInventoryItem] {
        var items: [ToolInventoryItem] = []
        for path in paths {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let servers = json["mcpServers"] as? [String: Any] ?? [:]
            for name in servers.keys {
                items.append(ToolInventoryItem(
                    id: "\(idPrefix):\(name)",
                    kind: .mcp,
                    agent: agent,
                    name: name,
                    displayName: ThirdPartyToolDisplay.shortenServer(name),
                    path: path,
                    modifiedAt: mtime(path)))
            }
        }
        return items
    }

    private static func shortPluginName(_ raw: String) -> String {
        // telegram@claude-plugins-official → telegram
        if let at = raw.firstIndex(of: "@") {
            return String(raw[..<at])
        }
        return ThirdPartyToolDisplay.shortenServer(raw)
    }

    private static func mtime(_ path: String?) -> Date? {
        guard let path else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? Date
    }

    private static func dedupe(_ items: [ToolInventoryItem]) -> [ToolInventoryItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    /// 粗解析 TOML：找出 `[prefix"name"]` / `[prefix.name]` 表名
    static func tomlTableNames(_ text: String, prefix: String) -> [String] {
        var names: [String] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), !trimmed.hasPrefix("[[") else { continue }
            let inner = String(trimmed.dropFirst().dropLast())
            guard inner.hasPrefix(prefix) else { continue }
            var name = String(inner.dropFirst(prefix.count))
            if name.hasPrefix("\"") && name.hasSuffix("\"") {
                name = String(name.dropFirst().dropLast())
            }
            if !name.isEmpty { names.append(name) }
        }
        return names
    }

    /// 在 `[table]` 段内找 `key = true/false`
    static func tomlBool(_ text: String, table: String, key: String) -> Bool? {
        let header = "[\(table)]"
        guard let range = text.range(of: header) else { return nil }
        let rest = text[range.upperBound...]
        let end = rest.range(of: "\n[")?.lowerBound ?? rest.endIndex
        let section = rest[..<end]
        for line in section.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("\(key)") else { continue }
            if t.contains("true") { return true }
            if t.contains("false") { return false }
        }
        return nil
    }

    /// 把库存条目与调用统计做模糊匹配
    public static func usage(for item: ToolInventoryItem,
                             stats: [ToolUsageStat]) -> ToolUsageStat? {
        let candidates = [item.displayName, item.name].map { $0.lowercased() }
        var best: ToolUsageStat?
        for stat in stats {
            let key = stat.toolKey.lowercased()
            let hit = candidates.contains { c in
                key == c || key.hasPrefix(c + "/") || key.contains("/" + c)
                    || key.contains(c)
            }
            guard hit else { continue }
            if let cur = best {
                let merged = ToolUsageStat(
                    toolKey: cur.toolKey,
                    callCount: cur.callCount + stat.callCount,
                    lastUsedAt: maxDate(cur.lastUsedAt, stat.lastUsedAt),
                    totalDurationSeconds: cur.totalDurationSeconds + stat.totalDurationSeconds)
                best = merged
            } else {
                best = stat
            }
        }
        return best
    }

    private static func maxDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        case (let x?, nil): return x
        case (nil, let y?): return y
        default: return nil
        }
    }
}
