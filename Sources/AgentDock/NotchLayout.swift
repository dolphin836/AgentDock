import AppKit
import AgentDockCore

/// 收起态与展开态共用的布局尺寸,保证两种形态宽度一致、中段永远压在(虚拟)刘海上
@MainActor
enum NotchLayout {
    static var mainScreen: NSScreen? { NSScreen.screens.first }

    static var barHeight: CGFloat {
        guard let s = mainScreen else { return 32 }
        return s.safeAreaInsets.top > 0 ? s.safeAreaInsets.top
            : s.frame.maxY - s.visibleFrame.maxY
    }

    /// 中段宽度:有物理刘海时与其精确对齐;无刘海时用虚拟刘海宽度
    static var centerWidth: CGFloat {
        guard let s = mainScreen, s.safeAreaInsets.top > 0,
              let left = s.auxiliaryTopLeftArea, let right = s.auxiliaryTopRightArea
        else { return 190 }
        return s.frame.width - left.width - right.width
    }

    /// 内容与左右边缘的间距
    static let edgePadding: CGFloat = 18

    /// 翼宽按内容动态测量:取所有活跃会话中左/右侧内容的最大宽度(左右对称取同一值)。
    /// 用"最宽者"而不是"当前轮播者",避免每 3 秒轮播时宽度跳动。
    static func wingWidth(sessions: [AgentSession], settings: AppSettings) -> CGFloat {
        let active = sessions.filter { $0.state.isActive }
        var widest: CGFloat = 0
        if active.isEmpty {
            let stats = SessionStats(sessions: sessions, settings: settings)
            widest = max(14 + 5 + measure(stats.sessionsText, size: 11, weight: .medium),
                         measure(stats.agentsText, size: 11, weight: .medium))
        } else {
            let elapsedReserve = measure("88m 88s", size: 11, weight: .medium) + 5
            for s in active {
                let left = 14 + 5 + measure(s.projectName, size: 11, weight: .semibold)
                let right = elapsedReserve
                    + measure(settings.label(for: s.state), size: 11, weight: .medium) + 5 + 13
                widest = max(widest, max(left, right))
            }
        }
        return min(280, max(110, widest + edgePadding + 8))
    }

    /// 总宽度 = 中段(刘海) + 两翼
    static func totalWidth(wing: CGFloat) -> CGFloat { centerWidth + wing * 2 }

    private static func measure(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight)]
        return ceil((text as NSString).size(withAttributes: attrs).width)
    }
}
