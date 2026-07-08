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
                            .font(Theme.mono(11, .semibold))
                            .foregroundStyle(Theme.text1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }),
                    center: AnyView(dotRow),
                    right: AnyView(HStack(spacing: 5) {
                        Text(elapsedText(primary, now: context.date))
                            .font(Theme.mono(10, .medium))
                            .foregroundStyle(Theme.text2)
                        HStack(spacing: 5) {
                            Text(primary.activityLabel(settings: settings))
                                .font(Theme.mono(10, .medium))
                                .foregroundStyle(primary.state.dotColor)
                                .lineLimit(1)
                            StatusGlyph(state: primary.state, size: 9)
                        }
                        .breathing(primary.state == .thinking || primary.state == .runningTool)
                    })
                )
            }
        }
    }

    /// 无运行任务时的汇总条:左翼 ❯ + session 总数,中段状态点,右翼 agent 数
    private var summaryBar: some View {
        let stats = SessionStats(sessions: sessions, settings: settings)
        return bar(
            left: AnyView(HStack(spacing: 5) {
                Text("❯")
                    .font(Theme.mono(10, .bold))
                    .foregroundStyle(Theme.phosphor.opacity(0.7))
                Text(stats.sessionsText)
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.text2)
            }),
            center: AnyView(dotRow),
            right: AnyView(Text(stats.agentsText)
                .font(Theme.mono(10, .medium))
                .foregroundStyle(Theme.text2))
        )
    }

    /// 一排状态点:每个会话一个点,颜色即状态,一眼看出「几个在跑、几个在等我」。
    /// 排序:等你处理 > 进行中 > 其他,重要的排前面(空间不够时先看到要紧的)
    private var dotRow: some View {
        let ordered = sessions.sorted { rank($0.state) < rank($1.state) }
        return HStack(spacing: 4.5) {
            ForEach(ordered.prefix(18)) { session in
                Circle()
                    .fill(session.state.dotColor)
                    .frame(width: 5, height: 5)
            }
        }
    }

    private func rank(_ state: SessionState) -> Int {
        switch state {
        case .waitingApproval: 0
        case .waitingInput: 1
        case .thinking, .runningTool: 2
        case .done, .idle: 3
        case .disconnected: 4
        }
    }

    /// 统一的三段条骨架:左右翼固定宽、内容与边缘留 edgePadding,总宽与展开态一致
    private func bar(left: AnyView, center: AnyView, right: AnyView) -> some View {
        HStack(spacing: 0) {
            left
                .padding(.leading, NotchLayout.edgePadding)
                .frame(width: NotchLayout.wingWidth, alignment: .leading)
                .frame(maxHeight: .infinity)
            center
                .padding(.horizontal, 6)
                .frame(width: NotchLayout.centerWidth)
                .frame(maxHeight: .infinity)
            right
                .padding(.trailing, NotchLayout.edgePadding)
                .frame(width: NotchLayout.wingWidth, alignment: .trailing)
                .frame(maxHeight: .infinity)
        }
        .frame(width: NotchLayout.totalWidth, height: NotchLayout.barHeight)
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
    /// 本轮耗时:从最近一次用户提交起算,退化为最后活动时间
    func turnElapsedText(now: Date = Date()) -> String {
        let promptEvents: Set<String> = ["UserPromptSubmit", "beforeSubmitPrompt", "task_started"]
        let start = recentEvents.last(where: { promptEvents.contains($0.name) })?.timestamp
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

