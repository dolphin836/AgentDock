import SwiftUI
import AppKit
import AgentDockCore

/// 收起态:与系统刘海融为一体的"延伸翼"。
/// 黑色区域 = 左翼 + 物理刘海 + 右翼,高度与刘海一致;
/// 左翼显示活动摘要(最多两行),右翼显示耗时 + 各会话状态点。
/// 多个活跃会话时每 3 秒轮播一个。无活跃会话时只剩状态点;完全无会话时隐形。
struct CapsuleView: View {
    let sessions: [AgentSession]
    let settings: AppSettings

    private var visible: [AgentSession] {
        sessions.filter { $0.state != .disconnected }
    }
    private var active: [AgentSession] {
        visible.filter { $0.state.isActive }
    }

    private var notchScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
    }
    private var notchHeight: CGFloat { notchScreen?.safeAreaInsets.top ?? 32 }
    private var notchWidth: CGFloat {
        guard let s = notchScreen,
              let left = s.auxiliaryTopLeftArea, let right = s.auxiliaryTopRightArea
        else { return 200 }
        return s.frame.width - left.width - right.width
    }

    var body: some View {
        if active.isEmpty {
            // 没有运行中的项目:不显示内容,但保留刘海大小的透明悬停区,便于展开查看闲置会话
            Color.clear
                .frame(width: notchWidth + 20, height: notchHeight)
                .contentShape(Rectangle())
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let primary = rotatingPrimary(at: context.date)
                // 左右翼等宽(取两侧内容较宽者,再设上限),保证整体居中后中间空位
                // 与物理刘海精确对齐,文字绝不滑入刘海底下,同时短文字不会撑出大黑条
                let wing: CGFloat = wingWidth(primary: primary)
                HStack(spacing: 0) {
                    // 左翼:摘要文字,靠刘海一侧对齐,超长截断
                    Group {
                        if let primary {
                            HStack(spacing: 5) {
                                Image(systemName: primary.kind.symbolName)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(summaryText(primary))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                    .minimumScaleFactor(0.8)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(width: wing, alignment: .trailing)
                    .frame(maxHeight: .infinity)
                    // 物理刘海占位:什么都不画,反正被摄像头区域盖住
                    Color.clear.frame(width: notchWidth)
                    // 右翼:仅当前轮播项目的状态点
                    Group {
                        if let primary {
                            StatusDot(state: primary.state)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(width: wing, alignment: .leading)
                    .frame(maxHeight: .infinity)
                }
                .frame(height: notchHeight)
                .background(NotchShape().fill(.black))
            }
        }
    }

    /// 按两侧实际内容测量翼宽:等宽对称,上限 250pt(超出交给两行/截断)
    private func wingWidth(primary: AgentSession?) -> CGFloat {
        let padding: CGFloat = 20  // 两侧 horizontal padding
        var left: CGFloat = 0
        let right: CGFloat = 13  // 单个状态点
        if let primary {
            left = 14 + 5 + measure(summaryText(primary), size: 10, weight: .medium)
        }
        return min(250, max(30, max(left, right)) + padding)
    }

    private func measure(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight)]
        return ceil((text as NSString).size(withAttributes: attrs).width)
    }

    /// 多个活跃会话每 3 秒轮播;没有活跃会话则不显示文字
    private func rotatingPrimary(at date: Date) -> AgentSession? {
        guard !active.isEmpty else { return nil }
        let index = Int(date.timeIntervalSinceReferenceDate / 3) % active.count
        return active[index]
    }

    private func summaryText(_ session: AgentSession) -> String {
        AgentSession.summaryLine(session, settings: settings)
    }
}

/// 单个状态点;等待审批时脉冲闪烁
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
