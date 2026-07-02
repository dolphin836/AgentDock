import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AgentDockCore

/// 会话宿主 App 图标:用发射脚本沿父进程链探测到的 .app 路径精确取图标,带缓存
@MainActor
enum HostAppIcon {
    private static var cache: [String: NSImage] = [:]

    /// 兜底:系统默认的 CLI(unix 可执行文件)图标
    private static let fallback = NSWorkspace.shared.icon(for: .unixExecutable)

    static func icon(forAppPath path: String?) -> NSImage {
        guard let path, !path.isEmpty else { return fallback }
        if let hit = cache[path] { return hit }
        guard FileManager.default.fileExists(atPath: path) else { return fallback }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache[path] = image
        return image
    }
}

/// 会话行:full = 进行中/等你(双行,信息全),compact = 历史(单行,压暗)
struct SessionRowView: View {
    let session: AgentSession
    let settings: AppSettings
    let compact: Bool
    @State private var hovered = false

    private var running: Bool {
        session.state == .thinking || session.state == .runningTool
    }

    var body: some View {
        Button {
            TerminalJumper.jump(toCwd: session.cwd)
        } label: {
            if compact { compactRow } else { fullRow }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    // MARK: 双行(进行中 / 等你)

    private var fullRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                AgentIcon(kind: session.kind, spinning: running, size: 11)
                    .frame(width: 14)
                Text(session.projectName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                if let text = session.latestText {
                    Text(text)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Text(settings.label(for: session.state))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(session.state.dotColor)
                StatusDot(state: session.state)
                Image(nsImage: HostAppIcon.icon(forAppPath: session.appPath))
                    .resizable()
                    .frame(width: 15, height: 15)
            }
            Text(metricsLine)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
                .padding(.leading, 21)  // 与名称对齐
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    // MARK: 单行(历史)

    private var compactRow: some View {
        HStack(spacing: 7) {
            AgentIcon(kind: session.kind, spinning: false, size: 10)
                .frame(width: 14)
                .opacity(0.5)
            Text(session.projectName)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
            if let model = session.metrics?.model {
                Text(model)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(timeText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Circle()
                .fill(session.state.dotColor.opacity(0.5))
                .frame(width: 5, height: 5)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .background(hovered ? Color.white.opacity(0.06) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    // MARK: 组件

    /// 任务名字色:运行中 = 绿,等你 = 状态暖色(黄/橙),其余白
    private var nameColor: Color {
        switch session.state {
        case .thinking, .runningTool: .green.opacity(0.95)
        case .waitingApproval: .yellow.opacity(0.95)
        case .waitingInput: .orange.opacity(0.95)
        default: .white.opacity(0.95)
        }
    }

    /// 等你的行有轻微暖色底;进行中靠动效与彩色状态字;hover 提亮
    private var rowBackground: Color {
        if hovered { return .white.opacity(0.09) }
        switch session.state {
        case .waitingApproval: return .yellow.opacity(0.09)
        case .waitingInput: return .orange.opacity(0.06)
        default: return .clear
        }
    }

    /// 一行等宽指标:Opus · ctx 37% · 68.4k tok · 6m
    private var metricsLine: String {
        var parts: [String] = []
        if let model = session.metrics?.model { parts.append(model) }
        if let pct = session.metrics?.contextPct { parts.append("context \(pct)%") }
        if let tokens = session.metrics?.totalTokens {
            parts.append(tokens >= 1000 ? String(format: "%.1fk tokens", Double(tokens) / 1000) : "\(tokens) tokens")
        }
        if let cost = session.metrics?.costUSD { parts.append(String(format: "$%.2f", cost)) }
        parts.append(timeText)
        return parts.joined(separator: " · ")
    }

    /// 运行中显示本轮耗时,其余显示距最后活动多久
    private var timeText: String {
        if session.state.isActive { return session.turnElapsedText() }
        let seconds = max(0, Int(Date().timeIntervalSince(session.lastActivity)))
        switch seconds {
        case ..<60: return settings.t("now", "刚刚")
        case ..<3600: return "\(seconds / 60)m"
        default: return "\(seconds / 3600)h\(seconds % 3600 / 60)m"
        }
    }
}
