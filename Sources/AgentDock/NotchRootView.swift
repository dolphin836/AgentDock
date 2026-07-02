import SwiftUI
import AppKit
import AgentDockCore

/// 顶层视图:收起态胶囊 + 悬停/告警展开面板
struct NotchRootView: View {
    let store: SessionStore
    let settings: AppSettings
    @State private var hovering = false
    @State private var alertExpanded = false
    @State private var lastAlertedIds: Set<String> = []

    private var expanded: Bool { hovering || alertExpanded }

    /// 刘海高度:内容必须从刘海下沿开始,否则被遮挡
    private var topInset: CGFloat {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }?.safeAreaInsets.top
            ?? NSScreen.main.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 24
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if expanded {
                    // 面板内容从刘海下沿开始,避免被遮挡
                    PanelView(store: store, settings: settings)
                        .padding(.top, topInset)
                        .background(
                            UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
                                .fill(.black)
                        )
                } else {
                    // 收起态贴着屏幕顶端,与物理刘海融为一体
                    CapsuleView(sessions: store.sessions, settings: settings)
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

    var isActive: Bool {
        switch self {
        case .thinking, .runningTool, .waitingApproval: true
        default: false
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
