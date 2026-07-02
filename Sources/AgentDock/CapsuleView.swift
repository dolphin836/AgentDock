import SwiftUI
import AgentDockCore

/// 收起态:刘海下沿的状态点条。无活跃会话时完全隐形。
struct CapsuleView: View {
    let sessions: [AgentSession]

    private var visible: [AgentSession] {
        sessions.filter { $0.state != .disconnected }
    }

    var body: some View {
        if visible.isEmpty {
            Color.clear.frame(width: 1, height: 1)
        } else {
            HStack(spacing: 6) {
                ForEach(visible) { session in
                    StatusDot(state: session.state)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black, in: Capsule())
        }
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
