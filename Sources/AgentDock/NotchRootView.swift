import SwiftUI
import AppKit
import AgentDockCore

/// 顶层视图:收起态胶囊 + 悬停/告警展开面板
struct NotchRootView: View {
    let store: SessionStore
    let settings: AppSettings
    @State private var hovering = false

    /// 有会话等待用户操作时保持展开提示,直到用户处理完
    private var expanded: Bool { hovering || !waitingIds.isEmpty }

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
                        .background(NotchShape(topRadius: 8, bottomRadius: 18).fill(.black))
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
