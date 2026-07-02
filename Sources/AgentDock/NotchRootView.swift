import SwiftUI
import AgentDockCore

/// 顶层视图:收起态胶囊 + 悬停/告警展开面板
struct NotchRootView: View {
    let store: SessionStore
    @State private var hovering = false
    @State private var alertExpanded = false
    @State private var lastAlertedIds: Set<String> = []

    private var expanded: Bool { hovering || alertExpanded }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if expanded {
                    PanelView(store: store)
                } else {
                    CapsuleView(sessions: store.sessions)
                }
            }
            .onHover { hovering = $0 }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.25), value: expanded)
        .onChange(of: waitingIds) { _, newIds in
            // 新出现的 waitingApproval 会话 → 自动展开 4 秒
            let fresh = newIds.subtracting(lastAlertedIds)
            lastAlertedIds = newIds
            guard !fresh.isEmpty else { return }
            alertExpanded = true
            Task {
                try? await Task.sleep(for: .seconds(4))
                alertExpanded = false
            }
        }
    }

    private var waitingIds: Set<String> {
        Set(store.sessions.filter { $0.state == .waitingApproval }.map(\.id))
    }
}

extension SessionState {
    var dotColor: Color {
        switch self {
        case .idle: .gray
        case .thinking: .blue
        case .runningTool: .green
        case .waitingApproval: .yellow
        case .done: .green.opacity(0.5)
        case .disconnected: .gray.opacity(0.4)
        }
    }

    var label: String {
        switch self {
        case .idle: "空闲"
        case .thinking: "思考中"
        case .runningTool: "执行工具"
        case .waitingApproval: "等待审批"
        case .done: "已完成"
        case .disconnected: "已断开"
        }
    }
}

extension AgentKind {
    var symbolName: String {
        switch self {
        case .claudeCode: "asterisk.circle.fill"
        case .codex: "chevron.left.forwardslash.chevron.right"
        }
    }
    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }
}
