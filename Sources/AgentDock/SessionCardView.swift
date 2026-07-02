import SwiftUI
import AgentDockCore

extension AgentSession {
    /// 收起态与卡片第一行共用的摘要:「文件/项目 · 状态」
    @MainActor
    static func summaryLine(_ session: AgentSession, settings: AppSettings) -> String {
        let detail = session.recentEvents.last(where: { $0.detail?.isEmpty == false })?.detail
        return "\(detail ?? session.projectName) · \(settings.label(for: session.state))"
    }
}

struct SessionCardView: View {
    let session: AgentSession
    let settings: AppSettings

    var body: some View {
        Button {
            TerminalJumper.jump(toCwd: session.cwd)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // 第一行:与收起态一致
                HStack(spacing: 6) {
                    Image(systemName: session.kind.symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(AgentSession.summaryLine(session, settings: settings))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    StatusDot(state: session.state)
                }
                // 第二行:模型 / ctx / 费用
                if let m = session.metrics {
                    HStack(spacing: 8) {
                        if let model = m.model { metric(model) }
                        if let pct = m.contextPct { metric("ctx \(pct)%") }
                        if let cost = m.costUSD { metric(String(format: "$%.2f", cost)) }
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func metric(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.white.opacity(0.1), in: Capsule())
    }
}
