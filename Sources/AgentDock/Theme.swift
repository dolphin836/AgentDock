import SwiftUI
import AgentDockCore

/// 终端仪表风格设计系统:等宽字体建立全局网格,纯黑底 + 少量高饱和语义色,
/// 状态用字形而非纯色点表达(monochrome-first:去掉颜色也能读懂)。
/// 参考 btop / lazygit / k9s / Claude Code 的公开设计规范。
enum Theme {
    // MARK: 语义色(高饱和,黑底上对比度足)

    /// 磷光绿:执行中 / 主强调色
    static let phosphor = Color(red: 0.32, green: 1.0, blue: 0.54)
    /// 终端青:思考中
    static let cyan = Color(red: 0.38, green: 0.91, blue: 0.96)
    /// 琥珀:等待输入
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.33)
    /// 警示黄:等待审批
    static let yellow = Color(red: 1.0, green: 0.89, blue: 0.36)
    /// 警报红:高用量
    static let red = Color(red: 1.0, green: 0.42, blue: 0.38)

    // MARK: 文本层级(白的不同透明度,保持单色可读)

    static let text1 = Color.white.opacity(0.92)   // 主内容
    static let text2 = Color.white.opacity(0.58)   // 次要
    static let text3 = Color.white.opacity(0.36)   // 辅助
    static let text4 = Color.white.opacity(0.22)   // 结构线/刻度底

    // MARK: 表面 / 描边(统一透明度,避免各处漂移)

    static let surface = Color.white.opacity(0.07)
    static let surfaceHover = Color.white.opacity(0.10)
    static let border = Color.white.opacity(0.18)
    static let borderSubtle = Color.white.opacity(0.10)

    /// 面板底:极轻冷绿偏色,比纯黑多一点「仪表」质感
    static let panelFill = Color(red: 0.02, green: 0.035, blue: 0.028)

    // MARK: 动效(短、软、少弹——高级感靠过渡而不是夸张)

    /// 展开/收起刘海
    static let expandSpring = Animation.spring(response: 0.34, dampingFraction: 0.86)
    /// Tab / 内容切换
    static let tabSwitch = Animation.easeInOut(duration: 0.2)
    /// 悬停、状态色变化
    static let soft = Animation.easeOut(duration: 0.16)
    /// 列表项出现
    static let appear = Animation.easeOut(duration: 0.22)
    /// 收起态任务轮播交叉淡入
    static let crossfade = Animation.easeInOut(duration: 0.28)

    /// 全局等宽字体:字符本身就是网格
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension SessionState {
    var dotColor: Color {
        switch self {
        case .idle: Theme.text3
        case .thinking: Theme.cyan
        case .runningTool: Theme.phosphor
        case .waitingInput: Theme.amber
        case .waitingApproval: Theme.yellow
        case .done: Theme.phosphor.opacity(0.45)
        case .disconnected: Theme.text3
        }
    }

    /// 语义字形:无色环境下也能区分状态
    var glyph: String {
        switch self {
        case .idle: "○"
        case .thinking: "◐"
        case .runningTool: "●"
        case .waitingInput: "◌"
        case .waitingApproval: "◉"
        case .done: "✓"
        case .disconnected: "✕"
        }
    }

    /// 运行中(统一口径):思考/执行/等待输入/需要审批都算——会话仍在进行,
    /// 参与收起态轮播与「N 个运行中」统计
    var isActive: Bool {
        switch self {
        case .thinking, .runningTool, .waitingInput, .waitingApproval: true
        case .idle, .done, .disconnected: false
        }
    }
}

/// 机器人本体(与菜单栏图标同一套 18pt 设计网格,SwiftUI 坐标系 y 向下)
struct RobotBody: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 18
        var path = Path()
        // 头
        path.addRoundedRect(in: CGRect(x: 3.2 * s, y: 4.8 * s, width: 11.6 * s, height: 10.6 * s),
                            cornerSize: CGSize(width: 2.8 * s, height: 2.8 * s))
        // 天线
        path.addRoundedRect(in: CGRect(x: 8.1 * s, y: 2.2 * s, width: 1.8 * s, height: 3.2 * s),
                            cornerSize: CGSize(width: 0.9 * s, height: 0.9 * s))
        // 双耳
        path.addRoundedRect(in: CGRect(x: 1.0 * s, y: 7.8 * s, width: 1.7 * s, height: 4.6 * s),
                            cornerSize: CGSize(width: 0.85 * s, height: 0.85 * s))
        path.addRoundedRect(in: CGRect(x: 15.3 * s, y: 7.8 * s, width: 1.7 * s, height: 4.6 * s),
                            cornerSize: CGSize(width: 0.85 * s, height: 0.85 * s))
        return path
    }
}

/// 品牌机器人图标:实心头 + 会左右张望的眼睛(面板头部用)
struct RobotGlyph: View {
    var size: CGFloat = 15
    var tint: Color = Theme.text1
    @State private var glance = false

    var body: some View {
        let s = size / 18
        ZStack(alignment: .topLeading) {
            RobotBody().fill(tint)
            ForEach([5.0, 9.8], id: \.self) { eyeX in
                Circle()
                    .fill(.black)
                    .frame(width: 3.2 * s, height: 3.2 * s)
                    .offset(x: (eyeX + (glance ? 0.7 : -0.7)) * s, y: 8.2 * s)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glance = true
            }
        }
    }
}

/// 自适应滚动:实测内容高度,不超上限时按自然高度渲染(顶对齐、面板贴合内容),
/// 超上限才转为固定高度的滚动区
struct AdaptiveScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if contentHeight > maxHeight {
            ScrollView(.vertical, showsIndicators: false) { measured }
                .frame(height: maxHeight)
        } else {
            measured
        }
    }

    private var measured: some View {
        content.onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
            contentHeight = height
        }
    }
}

/// 键帽组:每个键一个小圆角矩形(页脚提示与设置页共用)
struct Keycaps: View {
    let keys: [String]
    var size: CGFloat = 8.5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(Theme.mono(size, .semibold))
                    .foregroundStyle(Theme.text1)
                    .frame(minWidth: 10)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1.5)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(Theme.border, lineWidth: 1))
            }
        }
    }
}

/// 终端风格小按钮:描边 + 等宽字,用于设置页操作;悬停轻微提亮、按下略缩
struct TermButton: View {
    let title: String
    var color: Color = Theme.text2
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(9, .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
                .background(color.opacity(hovered ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(hovered ? 0.55 : 0.4), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .onHover { hovering in
            withAnimation(Theme.soft) { hovered = hovering }
        }
    }
}

/// 按下轻微缩小,松手回弹——比系统默认更克制
struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Theme.soft, value: configuration.isPressed)
    }
}

/// 呼吸灯:active 时整体透明度缓慢起伏,表达「正在进行」(幅度收一点,更不刺眼)
struct Breathing: ViewModifier {
    let active: Bool
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(active && dim ? 0.48 : 1)
            .animation(active
                       ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                       : .default,
                       value: dim)
            .onAppear { dim = true }
    }
}

extension View {
    /// 思考中/执行中的呼吸灯效果
    func breathing(_ active: Bool) -> some View {
        modifier(Breathing(active: active))
    }

    /// 语义色微光:运行中图标 / 激活 tab / 点亮刻度用,半径保持很小以免糊
    func phosphorGlow(_ color: Color = Theme.phosphor, active: Bool = true) -> some View {
        shadow(color: active ? color.opacity(0.45) : .clear, radius: 3.5, y: 0)
    }

    /// 列表项轻柔入场:淡入 + 轻微上移(不弹)
    func softAppear(delay: Double = 0) -> some View {
        modifier(SoftAppear(delay: delay))
    }
}

/// 首次出现时淡入上移;之后保持,避免列表刷新反复跳动
private struct SoftAppear: ViewModifier {
    var delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 4)
            .onAppear {
                guard !shown else { return }
                withAnimation(Theme.appear.delay(delay)) { shown = true }
            }
    }
}

/// 状态字形指示:取代纯色圆点;等待审批时脉冲闪烁
struct StatusGlyph: View {
    let state: SessionState
    var size: CGFloat = 10
    @State private var pulsing = false

    var body: some View {
        Text(state.glyph)
            .font(Theme.mono(size, .bold))
            .foregroundStyle(state.dotColor)
            .opacity(state == .waitingApproval && pulsing ? 0.25 : 1)
            .animation(state == .waitingApproval
                       ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                       : .default,
                       value: pulsing)
            .onAppear { pulsing = true }
    }
}
