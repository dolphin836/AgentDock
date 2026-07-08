import AppKit
import AgentDockCore

/// 收起态与展开态共用的布局尺寸:固定翼宽,总宽度恒定,任务轮播时不跳动
@MainActor
enum NotchLayout {
    /// 挂靠屏幕:跟随设置(默认主屏)
    static var mainScreen: NSScreen? { AppSettings.shared.targetScreen }

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

    /// 左右翼固定宽度:够放「图标 + 中等长度任务名」/「耗时 + 状态 + 点」,超长截断为 …
    static let wingWidth: CGFloat = 185
    /// 内容与左右边缘的间距
    static let edgePadding: CGFloat = 18

    /// 收起/展开统一的总宽度
    static var totalWidth: CGFloat { centerWidth + wingWidth * 2 }
}
