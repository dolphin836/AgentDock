import Foundation

/// 子任务聚合的纯展示逻辑:进度 detail 的生成与解析、UI 文案本地化、事件归类。
/// 抽成纯函数以便单测,避免只能人工肉眼验证 UI。
public enum SubagentDisplay {
    /// Aggregator 写入 subagentProgress 的 detail(计数在最前,便于安全回解)。
    public static func progressDetail(count: Int) -> String {
        "\(count) 个子任务运行中"
    }

    /// 从 subagentProgress 的 detail 中安全提取运行中子任务数;解析不出时回退 1
    /// (至少有一个才会产生 progress),绝不返回 0 造成「运行中却显示 0」。
    public static func runningCount(detail: String?) -> Int {
        guard let detail else { return 1 }
        var digits = ""
        for ch in detail {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return max(1, Int(digits) ?? 1)
    }

    /// 事件名是否为子任务聚合的进度事件(UI 归类为 .subtask,并用于取计数)。
    public static func isProgressEvent(_ name: String) -> Bool {
        name == "subagentProgress"
    }

    /// 事件名是否为子任务聚合的完成事件(映射为 thinking,不得污染当前工具展示)。
    public static func isCompleteEvent(_ name: String) -> Bool {
        name == "subagentComplete"
    }

    /// 运行中子任务的本地化文案:「子任务中… · N个运行中」/ 英文等价。
    public static func runningLabel(count: Int, chinese: Bool) -> String {
        chinese ? "子任务中… · \(count)个运行中"
                : "Subtasks… · \(count) running"
    }
}
