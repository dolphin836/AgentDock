import SwiftUI
import AppKit
import AgentDockCore

/// 顶层视图:收起态三段条 + 悬停/告警展开面板
struct NotchRootView: View {
    let store: SessionStore
    let settings: AppSettings
    let hoverState: HoverState

    /// 有会话需要用户审批时保持展开提示,直到用户处理完
    private var expanded: Bool { hoverState.hovering || !waitingIds.isEmpty }

    /// 顶栏高度:主屏有刘海用刘海高度,否则用菜单栏高度
    private var topInset: CGFloat {
        guard let screen = NSScreen.screens.first else { return 24 }
        return screen.safeAreaInsets.top > 0
            ? screen.safeAreaInsets.top
            : screen.frame.maxY - screen.visibleFrame.maxY
    }

    var body: some View {
        // 翼宽按内容动态测量,收起/展开共用同一总宽度
        let wing = NotchLayout.wingWidth(sessions: store.sessions, settings: settings)
        VStack(spacing: 0) {
            Group {
                if expanded {
                    // 面板内容从顶栏下沿开始,避免被刘海/菜单栏遮挡
                    PanelView(store: store, settings: settings,
                              width: NotchLayout.totalWidth(wing: wing))
                        .padding(.top, topInset)
                        .background(NotchShape(topRadius: 8, bottomRadius: 18).fill(.black))
                } else {
                    // 收起态贴着屏幕顶端,中段与(虚拟)刘海对齐
                    CapsuleView(sessions: store.sessions, settings: settings, wing: wing)
                }
            }
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size in
                hoverState.contentSize = size
            })
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
        case .waitingInput: .orange
        case .waitingApproval: .yellow
        case .done: .green.opacity(0.5)
        case .disconnected: .gray.opacity(0.4)
        }
    }

    /// 进行中:参与收起态轮播
    var isActive: Bool {
        switch self {
        case .thinking, .runningTool, .waitingApproval: true
        default: false
        }
    }
}

extension AgentKind {
    /// loading 图标:Claude CLI 的 ✳(雪花),Codex 的 ◆
    var symbolName: String {
        switch self {
        case .claudeCode: "asterisk"
        case .codex: "diamond.fill"
        }
    }
    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }
}

/// 进行中会话的旋转 loading 图标;非进行中静止显示
struct AgentIcon: View {
    let kind: AgentKind
    let spinning: Bool
    var size: CGFloat = 10
    @State private var spin = false

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white.opacity(spinning ? 0.95 : 0.6))
            .rotationEffect(.degrees(spin && spinning ? 360 : 0))
            .animation(spinning
                       ? .linear(duration: 2.5).repeatForever(autoreverses: false)
                       : .default,
                       value: spin)
            .onAppear { spin = true }
    }
}
