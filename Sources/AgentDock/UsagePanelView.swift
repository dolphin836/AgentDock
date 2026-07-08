import SwiftUI
import AgentDockCore

extension Notification.Name {
    static let agentDockRefreshUsage = Notification.Name("AgentDockRefreshUsage")
}

/// 独立的「用量」页:一个 agent 一组,每个限额窗口独立一行,大号刻度条 + 手动刷新
struct UsagePanelView: View {
    let store: SessionStore
    let settings: AppSettings
    @State private var refreshedAt: Date?
    @State private var todayStats: HistoryStore.ActivityStats?
    @State private var weekStats: HistoryStore.ActivityStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            refreshRow

            if store.claudeRateLimits == nil && store.codexRateLimits == nil {
                Text(settings.t("no usage data yet — use an agent once",
                                "暂无用量数据——任一 agent 活动后即出现"))
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            if let l = store.claudeRateLimits {
                agentGroup(
                    name: "CLAUDE CODE",
                    windows: [(settings.t("5-hour", "5小时"), l.fiveHourPct),
                              (settings.t("7-day", "7天"), l.sevenDayPct)],
                    updatedAt: l.updatedAt)
            }
            if let l = store.codexRateLimits {
                agentGroup(
                    name: "CODEX",
                    windows: [(settings.t("5-hour", "5小时"), l.fiveHourPct),
                              (settings.t("weekly", "每周"), l.sevenDayPct)],
                    updatedAt: l.updatedAt)
            }

            statsSection
        }
        .onAppear { reloadStats() }
    }

    // MARK: 活动统计(本地历史库)

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Theme.cyan.opacity(0.35))
                    .frame(width: 12, height: 1)
                Text(settings.t("ACTIVITY", "活动统计"))
                    .font(Theme.mono(10, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.text1)
                Rectangle()
                    .fill(Theme.text4.opacity(0.6))
                    .frame(height: 1)
            }
            .padding(.top, 10)
            .padding(.bottom, 2)

            if let todayStats {
                statsLine(label: settings.t("today", "今日"), stats: todayStats)
            }
            if let weekStats {
                statsLine(label: settings.t("7 days", "近7天"), stats: weekStats)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func statsLine(label: String, stats: HistoryStore.ActivityStats) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.text2)
                .frame(width: 64, alignment: .leading)
            Text(settings.t("worked \(duration(stats.activeSeconds))",
                            "工作 \(duration(stats.activeSeconds))"))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.phosphor.opacity(0.85))
            dividerDot
            Text("≈\(tokenText(stats.approxTokens)) tokens")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.text2)
            dividerDot
            Text(stats.waitCount == 0
                 ? settings.t("no waits", "无等待")
                 : settings.t("waited \(stats.waitCount)x · avg \(duration(stats.avgWaitSeconds))",
                              "等你 \(stats.waitCount) 次 · 平均 \(duration(stats.avgWaitSeconds))"))
                .font(Theme.mono(10))
                .foregroundStyle(stats.waitCount == 0 ? Theme.text3 : Theme.amber.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    private var dividerDot: some View {
        Text("·")
            .font(Theme.mono(10))
            .foregroundStyle(Theme.text4)
    }

    private func reloadStats() {
        let history = AppDelegate.history
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        Task.detached(priority: .utility) {
            let today = history.stats(since: dayStart, now: now)
            let week = history.stats(since: now.addingTimeInterval(-7 * 24 * 3600), now: now)
            await MainActor.run {
                todayStats = today
                weekStats = week
            }
        }
    }

    private func duration(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total < 60 { return "\(total)s" }
        if total < 3600 { return "\(total / 60)m" }
        return "\(total / 3600)h\(total % 3600 / 60)m"
    }

    private func tokenText(_ tokens: Int) -> String {
        switch tokens {
        case ..<1000: "\(tokens)"
        case ..<1_000_000: String(format: "%.1fk", Double(tokens) / 1000)
        default: String(format: "%.1fM", Double(tokens) / 1_000_000)
        }
    }

    // MARK: 刷新

    private var refreshRow: some View {
        HStack(spacing: 8) {
            Spacer()
            if let refreshedAt {
                Text(settings.t("refreshed \(ago(refreshedAt))", "已刷新 \(ago(refreshedAt))"))
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.text3)
            }
            TermButton(title: settings.t("REFRESH", "刷新"),
                       color: Theme.phosphor.opacity(0.85)) {
                NotificationCenter.default.post(name: .agentDockRefreshUsage, object: nil)
                refreshedAt = Date()
                reloadStats()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private func ago(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        return seconds < 60 ? settings.t("just now", "刚刚") : "\(seconds / 60)m"
    }

    // MARK: 每个 agent 一组

    private func agentGroup(name: String, windows: [(String, Int?)], updatedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Theme.phosphor.opacity(0.35))
                    .frame(width: 12, height: 1)
                Text(name)
                    .font(Theme.mono(10, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.text1)
                Rectangle()
                    .fill(Theme.text4.opacity(0.6))
                    .frame(height: 1)
                Text(freshness(updatedAt))
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.top, 10)
            .padding(.bottom, 2)

            ForEach(windows.filter { $0.1 != nil }, id: \.0) { window in
                usageLine(label: window.0, pct: window.1 ?? 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    /// 单个限额窗口:标签 / 长刻度条 / 百分比(右对齐,与组头新鲜度同列同字号)
    private func usageLine(label: String, pct: Int) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.text2)
                .frame(width: 64, alignment: .leading)
            TickBar(pct: pct, ticks: 66, tickWidth: 3, tickHeight: 14, spacing: 2.5)
            Spacer(minLength: 8)
            Text(String(format: "%3d%%", pct))
                .font(Theme.mono(9, .semibold))
                .foregroundStyle(pctColor(pct))
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func pctColor(_ pct: Int) -> Color {
        if pct >= 90 { return Theme.red }
        if pct >= 75 { return Theme.amber }
        return Theme.text1
    }

    private func freshness(_ updatedAt: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(updatedAt)) / 60
        if minutes < 1 { return settings.t("just now", "刚刚") }
        let text = minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h\(minutes % 60)m"
        return settings.t("\(text) ago", "\(text)前")
    }
}
