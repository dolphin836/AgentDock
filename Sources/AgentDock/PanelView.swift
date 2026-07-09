import SwiftUI
import AgentDockCore

/// 展开态面板:终端仪表风格——等宽网格、段落用「── LABEL ──」结构线分隔,
/// 按状态分组(进行中 → 等你 → 最近),纯黑底与刘海融合
struct PanelView: View {
    let store: SessionStore
    let settings: AppSettings
    let hoverState: HoverState
    let width: CGFloat

    private var running: [AgentSession] {
        store.sessions.filter { $0.state == .thinking || $0.state == .runningTool }
    }
    private var needsYou: [AgentSession] {
        store.sessions.filter { $0.state == .waitingApproval || $0.state == .waitingInput }
    }
    private var recent: [AgentSession] {
        store.sessions.filter {
            switch $0.state {
            case .idle, .done, .disconnected: true
            default: false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行固定:不参与 tab 切换动画,避免切到设置时整行跟着晃
            header
                .transaction { $0.animation = nil }

            tabBody
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .animation(Theme.tabSwitch, value: hoverState.activeTab)
        }
        .padding(.horizontal, NotchLayout.edgePadding - 6)
        .padding(.top, AppSettings.shared.panelPlacement == .menuBar ? 12 : 0)
        .padding(.bottom, 12)
        .frame(width: width, alignment: .topLeading)
    }

    @ViewBuilder private var tabBody: some View {
        switch hoverState.activeTab {
        case .sessions:
            Group {
                scrollable(sessionList)
                footer  // 页脚固定在滚动区之外,始终可见
            }
            .transition(.opacity)
        case .usage:
            scrollable(
                UsagePanelView(store: store, settings: settings)
                    .padding(.bottom, 8))
                .transition(.opacity)
        case .settings:
            scrollable(
                SettingsPanelView(settings: settings)
                    .padding(.bottom, 4))
                .transition(.opacity)
        }
    }

    // MARK: 内容滚动:内容不高时贴合高度,超出上限(会话多)时转为滚动,避免被窗口截断

    @ViewBuilder private func scrollable(_ content: some View) -> some View {
        AdaptiveScroll(maxHeight: 440) { content }
    }

    /// 会话列表(三个分组)
    @ViewBuilder private var sessionList: some View {
        VStack(alignment: .leading, spacing: 1) {
            if store.sessions.isEmpty {
                Text(settings.t("no agent sessions", "暂无 agent 会话"))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                if !running.isEmpty {
                    section(settings.t("RUNNING", "进行中"), tint: Theme.phosphor,
                            running, compact: false)
                }
                if !needsYou.isEmpty {
                    section(settings.t("NEEDS YOU", "等你处理"), tint: Theme.amber,
                            needsYou, compact: false)
                }
                if !recent.isEmpty {
                    section(settings.t("RECENT", "最近"), tint: Theme.text3,
                            recent, compact: true)
                }
            }
        }
    }

    // MARK: 底部页脚:快捷键提示 + 版本号

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.text4.opacity(0.6))
                .frame(height: 1)
                .padding(.top, 10)
            // 快捷键整体居中,项目间用分隔点;组合展示跟随设置
            HStack(spacing: 10) {
                shortcut(settings.toggleHotkey.keycaps, settings.t("show/hide", "展开/收起"))
                dividerDot
                shortcut(settings.allowHotkey.keycaps, settings.t("allow", "允许"))
                dividerDot
                shortcut(settings.denyHotkey.keycaps, settings.t("deny", "拒绝"))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private var dividerDot: some View {
        Text("·")
            .font(Theme.mono(9))
            .foregroundStyle(Theme.text4)
    }

    private func shortcut(_ keys: [String], _ label: String) -> some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(Theme.mono(8.5, .semibold))
                        .foregroundStyle(Theme.text1)
                        .frame(minWidth: 10)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1.5)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.border, lineWidth: 1))
                }
            }
            Text(label)
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text2)
        }
    }

    // MARK: 顶部:左标题 / 中统计 / 右 tab 切换

    private var header: some View {
        // 中间统计始终占位(非会话页透明),避免显隐导致标题行几何变化
        ZStack {
            HStack(spacing: 6) {
                RobotGlyph(size: 15)
                Text("AGENTDOCK")
                    .font(Theme.mono(11, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.text1)
                    .phosphorGlow(Theme.phosphor.opacity(0.7), active: true)
                Spacer(minLength: 8)
                tab("list.bullet", active: hoverState.activeTab == .sessions,
                    help: settings.t("Sessions", "会话")) {
                    hoverState.activeTab = .sessions
                }
                tab("chart.bar", active: hoverState.activeTab == .usage,
                    help: settings.t("Usage", "用量")) {
                    hoverState.activeTab = .usage
                }
                tab("gearshape", active: hoverState.activeTab == .settings,
                    help: settings.t("Settings", "设置")) {
                    hoverState.activeTab = .settings
                }
            }
            Text(SessionStats(sessions: store.sessions, settings: settings).headerText)
                .font(Theme.mono(9))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
                .opacity(hoverState.activeTab == .sessions ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .center)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(height: 28, alignment: .center)
    }

    /// 图标 tab:圆形描边统一轮廓,激活态磷光绿,切换带过渡动画
    private func tab(_ symbol: String, active: Bool, help: String,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Theme.phosphor : Theme.text3)
                .frame(width: 20, height: 20)
                .background(active ? Theme.phosphor.opacity(0.1) : .clear, in: Circle())
                .overlay(Circle().stroke(
                    active ? Theme.phosphor.opacity(0.55) : Theme.borderSubtle,
                    lineWidth: 1))
                .phosphorGlow(active: active)
                .contentShape(Circle())
                .animation(Theme.tabSwitch, value: active)
        }
        .buttonStyle(SoftPressStyle())
        .help(help)
    }

    // MARK: 分组:「── LABEL ────」结构线

    private func section(_ title: String, tint: Color,
                         _ sessions: [AgentSession], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(tint.opacity(0.35))
                    .frame(width: 12, height: 1)
                Text(title)
                    .font(Theme.mono(9, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(tint.opacity(0.85))
                Text("\(sessions.count)")
                    .font(Theme.mono(9, .semibold))
                    .foregroundStyle(tint.opacity(0.55))
                Rectangle()
                    .fill(tint.opacity(0.18))
                    .frame(height: 1)
            }
            .padding(.horizontal, 9)
            .padding(.top, 9)
            .padding(.bottom, 4)
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                SessionRowView(session: session, settings: settings, compact: compact,
                               approval: store.approval(for: session.id),
                               onDecision: { id, allow in store.resolveApproval(id: id, allow: allow) })
                    .softAppear(delay: Double(min(index, 6)) * 0.03)
            }
        }
        .animation(Theme.soft, value: sessions.map(\.id))
    }
}

/// 竖线刻度进度条:按百分比点亮;高用量时点亮部分转暖色警示。
/// 默认小号(列表页),用量页用大号参数。pct 变化时点亮刻度带轻微扫入感。
struct TickBar: View {
    let pct: Int
    var ticks: Int = 20
    var tickWidth: CGFloat = 1.5
    var tickHeight: CGFloat = 8
    var spacing: CGFloat = 1.5
    @State private var revealed = 0

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<ticks, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(color(at: i))
                    .frame(width: tickWidth, height: tickHeight)
                    .opacity(i < revealed ? 1 : 0.35)
                    .phosphorGlow(litColor(at: i), active: i == filled - 1 && filled > 0 && i < revealed)
            }
        }
        .onAppear { animateReveal() }
        .onChange(of: pct) { _, _ in animateReveal() }
    }

    private var filled: Int {
        Int((Double(min(max(pct, 0), 100)) / 100 * Double(ticks)).rounded())
    }

    private func animateReveal() {
        revealed = 0
        let target = max(filled, 1)
        for i in 0..<target {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.018) {
                withAnimation(.easeOut(duration: 0.12)) {
                    revealed = i + 1
                }
            }
        }
        if filled == 0 { revealed = 0 }
    }

    private func litColor(at index: Int) -> Color {
        if pct >= 90 { return Theme.red }
        if pct >= 75 { return Theme.amber }
        return Theme.phosphor
    }

    private func color(at index: Int) -> Color {
        guard index < filled else { return Theme.text4 }
        return litColor(at: index).opacity(pct >= 90 || pct >= 75 ? 1 : 0.8)
    }
}
