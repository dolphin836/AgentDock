import SwiftUI
import AppKit
import AgentDockCore

/// 顶层视图:收起态三段条 + 悬停/告警展开面板
struct NotchRootView: View {
    let store: SessionStore
    let settings: AppSettings
    let hoverState: HoverState

    /// 有会话需要用户审批时保持展开提示,直到用户处理完;⌘G 可手动固定展开
    private var expanded: Bool {
        hoverState.hovering || hoverState.pinnedOpen || !waitingIds.isEmpty
    }

    private var menuBarMode: Bool { settings.panelPlacement == .menuBar }

    /// 刘海模式:顶栏高度避开刘海/菜单栏;菜单栏下拉模式:面板直接从图标下方开始
    private var topInset: CGFloat {
        if menuBarMode { return 0 }
        guard let screen = settings.targetScreen ?? NSScreen.screens.first else { return 24 }
        return screen.safeAreaInsets.top > 0
            ? screen.safeAreaInsets.top
            : screen.frame.maxY - screen.visibleFrame.maxY
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    if expanded {
                        panelChrome
                    } else if !menuBarMode {
                        // 收起态仅刘海模式显示三段条;菜单栏模式收起时窗口隐藏
                        CapsuleView(sessions: store.sessions, settings: settings)
                    } else {
                        Color.clear.frame(width: 1, height: 1)
                    }
                }
                .onChange(of: expanded) { _, isExpanded in
                    // 收起后回到会话 tab,下次展开优先看任务
                    if !isExpanded { hoverState.activeTab = .sessions }
                }
                .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size in
                    hoverState.contentSize = size
                })
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Theme.expandSpring, value: expanded)
    }

    @ViewBuilder private var panelChrome: some View {
        let panel = PanelView(store: store, settings: settings, hoverState: hoverState,
                              width: NotchLayout.totalWidth)
            .padding(.top, topInset)
        let edge = LinearGradient(
            colors: [
                Theme.phosphor.opacity(0),
                Theme.phosphor.opacity(0.28),
                Theme.cyan.opacity(0.18),
                Theme.phosphor.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        if menuBarMode {
            // 菜单栏下拉:顶部箭头指向状态栏图标 + 圆角卡片(无磷光描边)
            VStack(spacing: 0) {
                MenuBarCaret()
                    .fill(Theme.panelFill)
                    .frame(width: 18, height: 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, max(0, hoverState.menuBarCaretX - 9))
                    // 箭头底边压进卡片 1pt,盖住接缝
                    .padding(.bottom, -1)
                    .zIndex(1)

                panel
                    .background(PanelSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.borderSubtle, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
            }
            .frame(width: NotchLayout.totalWidth)
        } else {
            panel
                .background(PanelSurface(shape: NotchShape(topRadius: 8, bottomRadius: 18)))
                .overlay {
                    NotchShape(topRadius: 8, bottomRadius: 18)
                        .stroke(edge, lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }

    /// 需要保持面板展开提醒的会话:等待审批,或 agent 主动提问等用户回答
    private var waitingIds: Set<String> {
        Set(store.sessions.filter { session in
            if session.state == .waitingApproval { return true }
            return session.state == .waitingInput
                && session.recentEvents.last?.tool.map(isUserFacingTool) == true
        }.map(\.id))
    }
}

/// 菜单栏下拉面板顶部的小三角,尖朝上指向状态栏图标;两侧向内凹的弧边
struct MenuBarCaret: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.midX, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.maxY)
        // 控制点偏向中轴,两侧边向内凹
        let insetX = rect.width * 0.12
        var path = Path()
        path.move(to: tip)
        path.addQuadCurve(to: right,
                          control: CGPoint(x: rect.midX + insetX, y: rect.midY))
        path.addLine(to: left)
        path.addQuadCurve(to: tip,
                          control: CGPoint(x: rect.midX - insetX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

extension AgentKind {
    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        }
    }
}

/// 进行中会话的旋转 loading 图标;非进行中静止显示。
/// 字形为自绘矢量(贴近各家品牌形状):Claude ✳ 星芒、Codex ◆ 菱形、Cursor 等距立方体。
struct AgentIcon: View {
    let kind: AgentKind
    let spinning: Bool
    var size: CGFloat = 10
    @State private var spin = false

    var body: some View {
        glyph
            .frame(width: size, height: size)
            .foregroundStyle(spinning ? Theme.phosphor : .white.opacity(0.55))
            .phosphorGlow(active: spinning)
            .rotationEffect(.degrees(spin && spinning ? 360 : 0))
            .animation(spinning
                       ? .linear(duration: 2.5).repeatForever(autoreverses: false)
                       : .default,
                       value: spin)
            .onAppear { spin = true }
    }

    @ViewBuilder private var glyph: some View {
        switch kind {
        case .claudeCode: ClaudeGlyph()
        case .codex: CodexGlyph()
        case .cursor: CursorGlyph()
        }
    }
}

/// Claude 的 ✳ 星芒:8 根圆头辐条,主轴略长
struct ClaudeGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            // 斜向辐条略短,更接近 Claude 星芒的错落感
            let r = i.isMultiple(of: 2) ? radius : radius * 0.78
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + cos(angle) * r,
                                     y: center.y + sin(angle) * r))
        }
        return path.strokedPath(StrokeStyle(lineWidth: radius * 0.3, lineCap: .round))
    }
}

/// Codex 的 ◆ 实心菱形(与其 CLI 界面字符一致)
struct CodexGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// Cursor 的等距立方体:正六边形分成三个面,用不同透明度做出立体感,
/// 单一着色下也成立(跟随 foregroundStyle)
struct CursorGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            // 顶点从正上方起顺时针:0 上、1 右上、2 右下、3 下、4 左下、5 左上
            let v = (0..<6).map { i -> CGPoint in
                let angle = CGFloat(i) * .pi / 3 - .pi / 2
                return CGPoint(x: center.x + cos(angle) * radius,
                               y: center.y + sin(angle) * radius)
            }
            ZStack {
                face([v[5], v[0], v[1], center]).opacity(1.0)    // 顶面最亮
                face([v[1], v[2], v[3], center]).opacity(0.62)   // 右面
                face([v[3], v[4], v[5], center]).opacity(0.8)    // 左面
            }
        }
    }

    private func face(_ points: [CGPoint]) -> some View {
        Path { p in
            p.move(to: points[0])
            for pt in points.dropFirst() { p.addLine(to: pt) }
            p.closeSubpath()
        }
        .fill()
    }
}
