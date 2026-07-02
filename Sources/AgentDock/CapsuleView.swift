import SwiftUI
import AppKit
import AgentDockCore

/// 收起态:主屏顶部的三段条(左翼 + 中段 + 右翼),总宽度与展开态一致。
/// 中段宽度 = 主屏物理刘海宽度(无刘海时用虚拟宽度),放不重要的内容(最新动态文本);
/// 左翼 = agent loading 图标 + 任务名;右翼 = 耗时 + 状态。
/// 进行中的任务每 3 秒轮播;没有进行中任务时展示汇总信息。
struct CapsuleView: View {
    let sessions: [AgentSession]
    let settings: AppSettings
    let wing: CGFloat

    private var active: [AgentSession] {
        sessions.filter { $0.state.isActive }
    }

    var body: some View {
        if active.isEmpty {
            summaryBar
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let primary = rotatingPrimary(at: context.date)
                bar(
                    left: AnyView(HStack(spacing: 5) {
                        AgentIcon(kind: primary.kind, spinning: true)
                        Text(primary.projectName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }),
                    center: primary.latestText ?? "",
                    right: AnyView(HStack(spacing: 5) {
                        Text(elapsedText(primary, now: context.date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                        Text(settings.label(for: primary.state))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(primary.state.dotColor)
                            .lineLimit(1)
                        StatusDot(state: primary.state)
                    })
                )
            }
        }
    }

    /// 无运行任务时的汇总条:左翼 session 总数,右翼 agent 数
    private var summaryBar: some View {
        let stats = SessionStats(sessions: sessions, settings: settings)
        return bar(
            left: AnyView(HStack(spacing: 5) {
                Image(systemName: "asterisk")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(stats.sessionsText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }),
            center: "",
            right: AnyView(Text(stats.agentsText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7)))
        )
    }

    /// 统一的三段条骨架:左右翼固定宽、内容与边缘留 edgePadding,总宽与展开态一致
    private func bar(left: AnyView, center: String, right: AnyView) -> some View {
        HStack(spacing: 0) {
            left
                .padding(.leading, NotchLayout.edgePadding)
                .frame(width: wing, alignment: .leading)
                .frame(maxHeight: .infinity)
            Text(center)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)
                .frame(width: NotchLayout.centerWidth)
                .frame(maxHeight: .infinity)
            right
                .padding(.trailing, NotchLayout.edgePadding)
                .frame(width: wing, alignment: .trailing)
                .frame(maxHeight: .infinity)
        }
        .frame(width: NotchLayout.totalWidth(wing: wing), height: NotchLayout.barHeight)
        .background(NotchShape().fill(.black))
    }

    /// 进行中任务每 3 秒轮播
    private func rotatingPrimary(at date: Date) -> AgentSession {
        let index = Int(date.timeIntervalSinceReferenceDate / 3) % active.count
        return active[index]
    }

    private func elapsedText(_ session: AgentSession, now: Date) -> String {
        session.turnElapsedText(now: now)
    }
}

extension AgentSession {
    /// 本轮耗时:从最近一次 UserPromptSubmit 起算,退化为最后活动时间
    func turnElapsedText(now: Date = Date()) -> String {
        let start = recentEvents.last(where: { $0.name == "UserPromptSubmit" })?.timestamp
            ?? lastActivity
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
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
