import SwiftUI
import AgentDockCore

/// 展开态面板:与刘海融合的黑色圆角卡片列表
struct PanelView: View {
    let store: SessionStore
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 8) {
            // 顶部汇总
            HStack {
                Text("AgentDock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(SessionStats(sessions: store.sessions, settings: settings).headerText)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
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
        .frame(width: NotchLayout.totalWidth)
    }
}
