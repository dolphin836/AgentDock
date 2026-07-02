import SwiftUI
import AppKit
import AgentDockCore

/// 收起态:主屏顶部的三段条(左翼 + 中段 + 右翼)。
/// 中段宽度 = 主屏物理刘海宽度(无刘海时用虚拟宽度),放不重要的内容(最新动态文本);
/// 左翼 = agent loading 图标 + 任务名;右翼 = 状态文案。
/// 进行中的任务每 3 秒轮播;没有进行中任务时只留透明悬停区。
struct CapsuleView: View {
    let sessions: [AgentSession]
    let settings: AppSettings

    private var active: [AgentSession] {
        sessions.filter { $0.state.isActive }
    }

    private var mainScreen: NSScreen? { NSScreen.screens.first }
    private var barHeight: CGFloat {
        guard let s = mainScreen else { return 32 }
        return s.safeAreaInsets.top > 0 ? s.safeAreaInsets.top
            : s.frame.maxY - s.visibleFrame.maxY
    }
    /// 中段宽度:有物理刘海时与其精确对齐;无刘海时用虚拟刘海宽度
    private var centerWidth: CGFloat {
        guard let s = mainScreen, s.safeAreaInsets.top > 0,
              let left = s.auxiliaryTopLeftArea, let right = s.auxiliaryTopRightArea
        else { return 190 }
        return s.frame.width - left.width - right.width
    }

    var body: some View {
        if active.isEmpty {
            // 没有进行中的任务:显示汇总信息(session 总数 + agent 数)
            summaryBar
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let primary = rotatingPrimary(at: context.date)
                let wing = wingWidth(primary, now: context.date)
                HStack(spacing: 0) {
                    // 左翼:loading 图标 + 任务名,左对齐
                    HStack(spacing: 5) {
                        AgentIcon(kind: primary.kind, spinning: true)
                        Text(primary.projectName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: wing, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    // 中段:最新动态文本,可被物理刘海遮挡,无所谓
                    Text(primary.latestText ?? "")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 6)
                        .frame(width: centerWidth)
                        .frame(maxHeight: .infinity)
                    // 右翼:耗时 + 状态文案 + 状态点,右对齐
                    HStack(spacing: 5) {
                        Text(elapsedText(primary, now: context.date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                        Text(settings.label(for: primary.state))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(primary.state.dotColor)
                            .lineLimit(1)
                        StatusDot(state: primary.state)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: wing, alignment: .trailing)
                    .frame(maxHeight: .infinity)
                }
                .frame(height: barHeight)
                .background(NotchShape().fill(.black))
                .id(primary.id)  // 轮播切换时整体过渡
                .transition(.opacity)
            }
        }
    }

    /// 无运行任务时的汇总条:左翼 session 总数,右翼 agent 数
    private var summaryBar: some View {
        let stats = SessionStats(sessions: sessions, settings: settings)
        let wing = max(60, max(measure(stats.sessionsText, size: 11, weight: .medium),
                               measure(stats.agentsText, size: 11, weight: .medium)) + 34)
        return HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "asterisk")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(stats.sessionsText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .frame(width: wing, alignment: .leading)
            .frame(maxHeight: .infinity)
            Color.clear.frame(width: centerWidth)
            Text(stats.agentsText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .frame(width: wing, alignment: .trailing)
                .frame(maxHeight: .infinity)
        }
        .frame(height: barHeight)
        .background(NotchShape().fill(.black))
    }

    /// 进行中任务每 3 秒轮播
    private func rotatingPrimary(at date: Date) -> AgentSession {
        let index = Int(date.timeIntervalSinceReferenceDate / 3) % active.count
        return active[index]
    }

    /// 左右翼等宽(取内容较宽者),保证中段精确压在(虚拟)刘海上
    private func wingWidth(_ primary: AgentSession, now: Date) -> CGFloat {
        let left = 14 + 5 + measure(primary.projectName, size: 11, weight: .semibold)
        let right = measure(elapsedText(primary, now: now), size: 11, weight: .medium) + 5
            + measure(settings.label(for: primary.state), size: 11, weight: .medium) + 5 + 13
        return min(260, max(50, max(left, right)) + 20)
    }

    /// 本轮耗时:从最近一次 UserPromptSubmit 起算,退化为最后活动时间
    private func elapsedText(_ session: AgentSession, now: Date) -> String {
        let start = session.recentEvents.last(where: { $0.name == "UserPromptSubmit" })?.timestamp
            ?? session.lastActivity
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }

    private func measure(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight)]
        return ceil((text as NSString).size(withAttributes: attrs).width)
    }
}

/// 汇总统计:session 总数 + agent 种类数(claude code 和 codex 算 2 个)
@MainActor
struct SessionStats {
    let sessions: [AgentSession]
    let settings: AppSettings

    var sessionCount: Int { sessions.count }
    var agentCount: Int { Set(sessions.map(\.kind)).count }
    var runningCount: Int { sessions.filter { $0.state.isActive }.count }

    var sessionsText: String {
        settings.t("\(sessionCount) sessions", "\(sessionCount) 个会话")
    }
    var agentsText: String {
        settings.t("\(agentCount) agents", "\(agentCount) 个 Agent")
    }
    var headerText: String {
        settings.t("\(sessionCount) sessions · \(agentCount) agents · \(runningCount) running",
                   "\(sessionCount) 个会话 · \(agentCount) 个 Agent · \(runningCount) 个运行中")
    }
}

extension AgentSession {
    /// 最新一条有内容的动态文本(中段展示用)
    var latestText: String? {
        recentEvents.last(where: { $0.detail?.isEmpty == false })?.detail
    }
}

/// 单个状态点;需要审批时脉冲闪烁
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
