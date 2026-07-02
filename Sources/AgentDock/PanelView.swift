import SwiftUI
import AgentDockCore

/// 展开态面板:按状态分组的行式列表(进行中 → 等你 → 最近),与刘海融合的纯黑底
struct PanelView: View {
    let store: SessionStore
    let settings: AppSettings
    let width: CGFloat

    private var running: [AgentSession] {
        store.sessions.filter { $0.state == .thinking || $0.state == .runningTool }
    }
    private var needsYou: [AgentSession] {
        store.sessions.filter { $0.state == .waitingApproval || $0.state == .waitingInput }
    }
    private var recent: [AgentSession] {
        store.sessions.filter {
            switch $0.state {
            case .idle, .done, .disconnected: true
            default: false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            if store.sessions.isEmpty {
                Text(settings.t("No agent sessions", "暂无 Agent 会话"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                if !running.isEmpty {
                    section(settings.t("RUNNING", "进行中"), running, compact: false)
                }
                if !needsYou.isEmpty {
                    section(settings.t("NEEDS YOU", "等你处理"), needsYou, compact: false)
                }
                if !recent.isEmpty {
                    section(settings.t("RECENT", "最近"), recent, compact: true)
                }
            }
        }
        .padding(.horizontal, NotchLayout.edgePadding - 6)
        .padding(.bottom, 12)
        .frame(width: width)
    }

    // MARK: 顶部:左标题 / 中限额 / 右统计

    private var header: some View {
        ZStack {
            HStack {
                Text("AgentDock")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(SessionStats(sessions: store.sessions, settings: settings).headerText)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            if let limits = limitsText {
                Text(limits)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
    }

    private func section(_ title: String, _ sessions: [AgentSession], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 9)
                .padding(.top, 8)
                .padding(.bottom, 3)
            ForEach(sessions) { session in
                SessionRowView(session: session, settings: settings, compact: compact)
            }
        }
    }

    /// 顶部中间的限额:✳ Claude 5h/7d · ◆ Codex 5h/wk
    private var limitsText: String? {
        var parts: [String] = []
        if let l = store.claudeRateLimits {
            parts.append("✳ 5h \(l.fiveHourPct.map { "\($0)%" } ?? "--") 7d \(l.sevenDayPct.map { "\($0)%" } ?? "--")")
        }
        if let l = store.codexRateLimits {
            parts.append("◆ 5h \(l.fiveHourPct.map { "\($0)%" } ?? "--") wk \(l.sevenDayPct.map { "\($0)%" } ?? "--")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }
}
