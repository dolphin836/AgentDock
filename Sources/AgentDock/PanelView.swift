import SwiftUI
import AgentDockCore

/// 展开态面板:与刘海融合的黑色圆角卡片列表
struct PanelView: View {
    let store: SessionStore
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 8) {
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
        .padding(12)
        .frame(width: 380)
        .background(
            UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
                .fill(.black)
        )
    }
}
