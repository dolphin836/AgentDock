import SwiftUI
import AgentDockCore

/// 收起态:刘海下沿的活动摘要条。
/// 有活跃会话时显示「文件/项目 · 状态 · 耗时」,其余会话折叠为状态点;无会话时完全隐形。
struct CapsuleView: View {
    let sessions: [AgentSession]
    let settings: AppSettings

    private var visible: [AgentSession] {
        sessions.filter { $0.state != .disconnected }
    }
    /// 最近有动静的活跃会话,作为摘要主体
    private var primary: AgentSession? {
        visible.first { $0.state.isActive } ?? visible.first
    }

    var body: some View {
        if let primary {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 6) {
                    Image(systemName: primary.kind.symbolName)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(summaryText(primary, now: context.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    ForEach(visible.filter { $0.id != primary.id }) { session in
                        StatusDot(state: session.state)
                    }
                    StatusDot(state: primary.state)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black, in: Capsule())
            }
        } else {
            Color.clear.frame(width: 1, height: 1)
        }
    }

    private func summaryText(_ session: AgentSession, now: Date) -> String {
        // 最近一条带 detail 的事件(通常是正在操作的文件/工具)
        let detail = session.recentEvents.last(where: { $0.detail?.isEmpty == false })?.detail
        var parts = [detail ?? session.projectName, settings.label(for: session.state)]
        if session.state.isActive {
            parts.append(elapsedText(session, now: now))
        }
        return parts.joined(separator: " · ")
    }

    /// 本轮耗时:从最近一次 UserPromptSubmit 起算,退化为最后活动时间
    private func elapsedText(_ session: AgentSession, now: Date) -> String {
        let start = session.recentEvents.last(where: { $0.name == "UserPromptSubmit" })?.timestamp
            ?? session.lastActivity
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}

/// 单个状态点;等待审批时脉冲闪烁
struct StatusDot: View {
    let state: SessionState
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(state.dotColor)
            .frame(width: 8, height: 8)
            .opacity(state == .waitingApproval && pulsing ? 0.25 : 1)
            .animation(state == .waitingApproval
                       ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                       : .default,
                       value: pulsing)
            .onAppear { pulsing = true }
    }
}
