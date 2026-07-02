import SwiftUI
import AgentDockCore

struct SessionCardView: View {
    let session: AgentSession

    var body: some View {
        Button {
            TerminalJumper.jump(toCwd: session.cwd)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: session.kind.symbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    StatusDot(state: session.state)
                    Text(session.state.label)
                        .font(.system(size: 11))
                        .foregroundStyle(session.state.dotColor)
                }
                if let m = session.metrics {
                    HStack(spacing: 8) {
                        if let model = m.model { metric(model) }
                        if let pct = m.contextPct { metric("ctx \(pct)%") }
                        if let cost = m.costUSD { metric(String(format: "$%.2f", cost)) }
                    }
                }
                ForEach(session.recentEvents.suffix(3), id: \.timestamp) { event in
                    Text("· \(event.name)\(event.detail.map { " — \($0)" } ?? "")")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
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
