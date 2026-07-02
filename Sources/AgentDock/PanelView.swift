import SwiftUI
import AgentDockCore

/// 展开态面板:与刘海融合的黑色圆角卡片列表
struct PanelView: View {
    let store: SessionStore
    let settings: AppSettings
    let width: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            // 顶部汇总:左标题 / 中限额 / 右统计
            ZStack {
                HStack {
                    Text("AgentDock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text(SessionStats(sessions: store.sessions, settings: settings).headerText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
                if let limits = limitsText {
                    Text(limits)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 2)
            if store.sessions.isEmpty {
                Text(settings.t("No agent sessions", "暂无 Agent 会话"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.sessions) { session in
                    SessionCardView(session: session, settings: settings)
                }
            }
        }
        .padding(.horizontal, NotchLayout.edgePadding)
        .padding(.vertical, 12)
        .frame(width: width)
    }

    /// 顶部中间的限额文案:✳ Claude 5h/7d · ◆ Codex 5h/wk
    private var limitsText: String? {
        var parts: [String] = []
        if let l = store.claudeRateLimits {
            parts.append("✳ 5h \(l.fiveHourPct.map { "\($0)%" } ?? "--") · 7d \(l.sevenDayPct.map { "\($0)%" } ?? "--")")
        }
        if let l = store.codexRateLimits {
            parts.append("◆ 5h \(l.fiveHourPct.map { "\($0)%" } ?? "--") · wk \(l.sevenDayPct.map { "\($0)%" } ?? "--")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }
}
