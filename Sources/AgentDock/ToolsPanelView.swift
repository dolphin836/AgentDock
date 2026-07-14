import SwiftUI
import AppKit
import AgentDockCore

/// 「工具」页:按 Agent 分组展示已安装插件 / Skill / MCP，可收起展开；
/// hover 时显示检测更新 / 更新 / 卸载（按 agent 能力分层）。
struct ToolsPanelView: View {
    let settings: AppSettings
    @State private var groups: [ToolInventoryGroup] = []
    @State private var usageByKind: [AgentKind: [ToolUsageStat]] = [:]
    @State private var summaryByKind: [AgentKind: (count: Int, last: Date?, duration: Double)] = [:]
    @State private var expanded: Set<AgentKind> = []
    @State private var scannedAt: Date?
    @State private var scanning = false
    @State private var busyId: String?
    @State private var statusText: String?
    @State private var statusOK = true
    /// 检测更新后记下「有新版本」的条目 → 最新版本号
    @State private var updateAvailable: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            refreshRow
            if let statusText {
                Text(statusText)
                    .font(Theme.mono(9))
                    .foregroundStyle(statusOK ? Theme.phosphor.opacity(0.85) : Theme.amber.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 2)
                    .lineLimit(2)
            }

            if groups.isEmpty && !scanning {
                Text(settings.t("no tools found — install a plugin, skill, or MCP",
                                "未发现工具——安装插件 / Skill / MCP 后会出现"))
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            ForEach(groups) { group in
                agentSection(group)
            }
        }
        .onAppear { reload() }
    }

    // MARK: - 刷新

    private var refreshRow: some View {
        HStack(spacing: 8) {
            Text(settings.t("Installed tools", "已安装工具"))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text3)
            Spacer()
            if let scannedAt {
                Text(settings.t("scanned \(ago(scannedAt))", "已扫描 \(ago(scannedAt))"))
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.text3)
            }
            TermButton(title: settings.t("REFRESH", "刷新"),
                       color: Theme.phosphor.opacity(0.85)) {
                reload()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private func reload() {
        scanning = true
        let history = AppDelegate.history
        let since = Date().addingTimeInterval(-30 * 24 * 3600)
        Task.detached(priority: .utility) {
            let scanned = ToolInventoryScanner.scan()
            var usage: [AgentKind: [ToolUsageStat]] = [:]
            var summary: [AgentKind: (count: Int, last: Date?, duration: Double)] = [:]
            for kind in AgentKind.allCases {
                usage[kind] = history.toolUsage(kind: kind, since: since)
                let s = history.toolUsageSummary(kind: kind, since: since)
                summary[kind] = (s.count, s.lastUsedAt, s.totalDurationSeconds)
            }
            await MainActor.run {
                groups = scanned
                usageByKind = usage
                summaryByKind = summary
                scannedAt = Date()
                scanning = false
                expanded = expanded.intersection(Set(scanned.map(\.agent)))
                // 清掉已不存在条目的更新标记
                let ids = Set(scanned.flatMap(\.items).map(\.id))
                updateAvailable = updateAvailable.filter { ids.contains($0.key) }
            }
        }
    }

    // MARK: - Agent 分组

    private func agentSection(_ group: ToolInventoryGroup) -> some View {
        let isOpen = expanded.contains(group.agent)
        return VStack(alignment: .leading, spacing: 1) {
            Button {
                // 关掉隐式动画:分组插入/删除会和外层 AdaptiveScroll 抢布局,偶发整页闪一下
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    if isOpen { expanded.remove(group.agent) }
                    else { expanded.insert(group.agent) }
                }
            } label: {
                groupHeader(group, open: isOpen)
            }
            .buttonStyle(.plain)

            if isOpen {
                let stats = usageByKind[group.agent] ?? []
                ForEach(sortedItems(group.items, stats: stats)) { item in
                    ToolItemRowView(
                        item: item,
                        usage: ToolInventoryScanner.usage(for: item, stats: stats),
                        settings: settings,
                        busy: busyId == item.id,
                        updateHint: updateAvailable[item.id],
                        onAction: { action in handle(action, item: item) }
                    )
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func sortedItems(_ items: [ToolInventoryItem],
                             stats: [ToolUsageStat]) -> [ToolInventoryItem] {
        items.sorted { a, b in
            let ca = ToolInventoryScanner.usage(for: a, stats: stats)?.callCount ?? 0
            let cb = ToolInventoryScanner.usage(for: b, stats: stats)?.callCount ?? 0
            if ca != cb { return ca > cb }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private func groupHeader(_ group: ToolInventoryGroup, open: Bool) -> some View {
        let summary = summaryByKind[group.agent]
        return HStack(spacing: 6) {
            Text(open ? "▾" : "▸")
                .font(Theme.mono(10, .bold))
                .foregroundStyle(Theme.phosphor.opacity(0.7))
                .frame(width: 12, alignment: .center)
            AgentIcon(kind: group.agent, spinning: false, size: 9)
            Text(group.agent.displayName.uppercased())
                .font(Theme.mono(10, .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.text1)
            Text(summaryLine(group, summary: summary))
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Rectangle()
                .fill(Theme.text4.opacity(0.6))
                .frame(height: 1)
                .frame(minWidth: 12)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
    }

    private func summaryLine(_ group: ToolInventoryGroup,
                             summary: (count: Int, last: Date?, duration: Double)?) -> String {
        var parts: [String] = []
        if group.pluginCount > 0 {
            parts.append(settings.t("\(group.pluginCount) plugins",
                                    "\(group.pluginCount) 插件"))
        }
        if group.mcpCount > 0 {
            parts.append(settings.t("\(group.mcpCount) mcp",
                                    "\(group.mcpCount) MCP"))
        }
        if group.skillCount > 0 {
            parts.append(settings.t("\(group.skillCount) skills",
                                    "\(group.skillCount) Skill"))
        }
        if let summary, summary.count > 0 {
            parts.append(settings.t("\(summary.count) calls",
                                    "\(summary.count) 次调用"))
            if summary.duration > 0 {
                parts.append(formatDuration(summary.duration))
            }
            if let last = summary.last {
                parts.append(relative(last))
            }
        }
        return parts.isEmpty ? "" : "· " + parts.joined(separator: " · ")
    }

    // MARK: - 操作

    private func handle(_ action: ToolManageAction, item: ToolInventoryItem) {
        if action == .uninstall {
            let title = settings.t("Uninstall \(item.displayName)?",
                                   "卸载 \(item.displayName)？")
            let body = settings.t("This cannot be undone from AgentDock.",
                                  "卸载后需重新安装才能恢复。")
            guard confirm(title: title, body: body,
                          confirmTitle: settings.t("UNINSTALL", "卸载")) else { return }
        }
        busyId = item.id
        statusText = settings.t("Working…", "处理中…")
        statusOK = true
        Task {
            let result = await ToolPluginManager.perform(action, item: item)
            await MainActor.run {
                busyId = nil
                statusOK = result.ok
                statusText = localizeResult(result, action: action, item: item)
                if let latest = result.latestVersion, action == .checkUpdate {
                    updateAvailable[item.id] = latest
                }
                if action == .update, result.ok {
                    updateAvailable[item.id] = nil
                }
                if action == .uninstall, result.ok {
                    updateAvailable[item.id] = nil
                    reload()
                } else if action == .update, result.ok {
                    reload()
                }
            }
        }
    }

    private func localizeResult(_ result: ToolManageResult,
                                action: ToolManageAction,
                                item: ToolInventoryItem) -> String {
        // 管理器返回英文中性句；按动作给中英对照
        if !result.ok {
            return result.message
        }
        switch action {
        case .checkUpdate:
            if let latest = result.latestVersion {
                return settings.t("Update available · v\(latest)",
                                  "有可用更新 · v\(latest)")
            }
            if result.message.contains("Up to date") {
                return settings.t(result.message, "已是最新 · \(item.version.map { "v\($0)" } ?? "")")
            }
            if result.message.contains("Marketplace refreshed") {
                let cur = item.version.map { "v\($0)" } ?? ""
                return settings.t("Marketplace refreshed · current \(cur) · tap Update",
                                  "市场已刷新 · 当前 \(cur) · 可点更新")
            }
            return result.message
        case .update:
            return settings.t(result.message, result.message.replacingOccurrences(of: "Updated", with: "已更新"))
        case .uninstall:
            return settings.t("Uninstalled \(item.displayName)", "已卸载 \(item.displayName)")
        case .openInHost:
            return settings.t("Opened Cursor — manage in Customize",
                              "已打开 Cursor — 请在 Customize 中管理")
        }
    }

    private func confirm(title: String, body: String, confirmTitle: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: settings.t("Cancel", "取消"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return settings.t("just now", "刚刚") }
        if seconds < 3600 {
            let n = max(1, seconds / 60)
            return settings.t("\(n) minutes ago", "\(n) 分钟前")
        }
        if seconds < 86_400 {
            let n = max(1, seconds / 3600)
            return settings.t("\(n) hours ago", "\(n) 小时前")
        }
        let days = seconds / 86_400
        if days < 30 {
            return settings.t("\(days) days ago", "\(days) 天前")
        }
        let months = max(1, days / 30)
        return settings.t("\(months) months ago", "\(months) 个月前")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 {
            return settings.t("\(total) sec", "\(total) 秒")
        }
        if total < 3600 {
            let m = total / 60
            let s = total % 60
            if s == 0 { return settings.t("\(m) min", "\(m) 分钟") }
            return settings.t("\(m) min \(s) sec", "\(m) 分 \(s) 秒")
        }
        let h = total / 3600
        let m = (total % 3600) / 60
        if m == 0 { return settings.t("\(h) hours", "\(h) 小时") }
        return settings.t("\(h) hours \(m) min", "\(h) 小时 \(m) 分")
    }

    private func ago(_ date: Date) -> String { relative(date) }
}

// MARK: - 单行（hover 显示操作）

private struct ToolItemRowView: View {
    let item: ToolInventoryItem
    let usage: ToolUsageStat?
    let settings: AppSettings
    let busy: Bool
    let updateHint: String?
    let onAction: (ToolManageAction) -> Void
    @State private var hovered = false

    private var hasUsage: Bool { (usage?.callCount ?? 0) > 0 }
    private var actions: [ToolManageAction] { ToolPluginManager.actions(for: item) }

    var body: some View {
        HStack(spacing: 8) {
            Text(kindBadge)
                .font(Theme.mono(8, .bold))
                .tracking(0.6)
                .foregroundStyle(kindColor.opacity(0.9))
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.text1)
                        .lineLimit(1)
                    if let version = item.version, !version.isEmpty {
                        Text("v\(version)")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.text3)
                    }
                    if let updateHint {
                        Text(settings.t("↑ v\(updateHint)", "↑ v\(updateHint)"))
                            .font(Theme.mono(8.5, .semibold))
                            .foregroundStyle(Theme.amber.opacity(0.9))
                    }
                }
                if hasUsage, let last = usage?.lastUsedAt {
                    Text(settings.t("last used \(relative(last))",
                                    "上次使用 \(relative(last))"))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.cyan.opacity(0.8))
                        .lineLimit(1)
                } else if let path = item.path {
                    Text(shortPath(path))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)

            if hovered && !actions.isEmpty {
                actionButtons
                    .transition(.opacity)
            } else if hasUsage, let usage {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(settings.t("\(usage.callCount) calls", "\(usage.callCount) 次"))
                        .font(Theme.mono(10, .semibold))
                        .foregroundStyle(Theme.cyan.opacity(0.85))
                    if usage.totalDurationSeconds > 0 {
                        Text(formatDuration(usage.totalDurationSeconds))
                            .font(Theme.mono(8.5))
                            .foregroundStyle(Theme.text2)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(hovered ? Theme.surfaceHover : .clear,
                    in: RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Theme.soft) { hovered = hovering }
        }
        .help(item.path ?? item.name)
        .opacity(busy ? 0.55 : 1)
        .allowsHitTesting(!busy)
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            ForEach(actions, id: \.self) { action in
                TermButton(title: label(for: action), color: color(for: action)) {
                    onAction(action)
                }
            }
        }
    }

    private func label(for action: ToolManageAction) -> String {
        switch action {
        case .checkUpdate: settings.t("CHECK", "检测")
        case .update: settings.t("UPDATE", "更新")
        case .uninstall: settings.t("REMOVE", "卸载")
        case .openInHost: settings.t("CURSOR", "Cursor")
        }
    }

    private func color(for action: ToolManageAction) -> Color {
        switch action {
        case .checkUpdate: Theme.cyan.opacity(0.85)
        case .update: Theme.phosphor.opacity(0.9)
        case .uninstall: Theme.red.opacity(0.85)
        case .openInHost: Theme.text2
        }
    }

    private var kindBadge: String {
        switch item.kind {
        case .plugin: "PLUG"
        case .skill: "SKILL"
        case .mcp: "MCP"
        }
    }

    private var kindColor: Color {
        switch item.kind {
        case .plugin: Theme.phosphor
        case .skill: Theme.amber
        case .mcp: Theme.cyan
        }
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }

    private func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return settings.t("just now", "刚刚") }
        if seconds < 3600 {
            let n = max(1, seconds / 60)
            return settings.t("\(n) minutes ago", "\(n) 分钟前")
        }
        if seconds < 86_400 {
            let n = max(1, seconds / 3600)
            return settings.t("\(n) hours ago", "\(n) 小时前")
        }
        let days = seconds / 86_400
        if days < 30 { return settings.t("\(days) days ago", "\(days) 天前") }
        let months = max(1, days / 30)
        return settings.t("\(months) months ago", "\(months) 个月前")
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return settings.t("\(total) sec", "\(total) 秒") }
        if total < 3600 {
            let m = total / 60
            let s = total % 60
            if s == 0 { return settings.t("\(m) min", "\(m) 分钟") }
            return settings.t("\(m) min \(s) sec", "\(m) 分 \(s) 秒")
        }
        let h = total / 3600
        let m = (total % 3600) / 60
        if m == 0 { return settings.t("\(h) hours", "\(h) 小时") }
        return settings.t("\(h) hours \(m) min", "\(h) 小时 \(m) 分")
    }
}
