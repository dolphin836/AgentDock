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

struct SessionCardView: View {
    let session: AgentSession
    let settings: AppSettings
    @State private var hovered = false

    /// 运行中的卡片整体"点亮",非运行的整体压暗
    private var running: Bool {
        session.state == .thinking || session.state == .runningTool
    }
    private var needsUser: Bool {
        session.state == .waitingApproval || session.state == .waitingInput
    }
    /// 主要文字不透明度:运行/需要用户 > 等待 > 断开
    private var primaryOpacity: Double {
        if running || needsUser { return 1.0 }
        return session.state == .disconnected ? 0.35 : 0.55
    }

    var body: some View {
        Button {
            TerminalJumper.jump(toCwd: session.cwd)
        } label: {
            HStack(spacing: 10) {
                // 左侧状态色条:运行中/需要用户时点亮
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(running || needsUser ? session.state.dotColor : Color.white.opacity(0.12))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 5) {
                    // 第一行:与收起态一致 + 末尾 app 图标
                    HStack(spacing: 6) {
                        AgentIcon(kind: session.kind, spinning: running, size: 12)
                            .opacity(primaryOpacity)
                        Text(session.projectName)
                            .font(.system(size: 13, weight: running ? .bold : .semibold))
                            .foregroundStyle(.white.opacity(primaryOpacity))
                            .lineLimit(1)
                        if let text = session.latestText {
                            Text(text)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(primaryOpacity * 0.45))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        Spacer(minLength: 8)
                        Text(settings.label(for: session.state))
                            .font(.system(size: 11, weight: running || needsUser ? .semibold : .regular))
                            .foregroundStyle(session.state.dotColor
                                .opacity(running || needsUser ? 1 : 0.6))
                        StatusDot(state: session.state)
                            .opacity(running || needsUser ? 1 : 0.5)
                        Image(nsImage: HostAppIcon.icon(forAppPath: session.appPath))
                            .resizable()
                            .frame(width: 16, height: 16)
                            .opacity(primaryOpacity)
                            .grayscale(running || needsUser ? 0 : 0.8)
                    }
                    // 第二行:模型 / ctx / token 消耗 / 时间(缺失的字段用 -- 占位)
                    HStack(spacing: 8) {
                        metric(session.metrics?.model ?? "--")
                        metric("ctx \(session.metrics?.contextPct.map { "\($0)%" } ?? "--")")
                        metric(tokensText)
                        metric(timeText)
                    }
                    .opacity(running || needsUser ? 1 : 0.55)
                }
            }
            .padding(10)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    /// 背景:hover 最亮 > 需要审批(黄) > 等待输入(橙) > 运行中(状态色微光) > 其他压暗
    private var cardBackground: Color {
        if hovered { return .white.opacity(0.16) }
        switch session.state {
        case .waitingApproval: return .yellow.opacity(0.10)
        case .waitingInput: return .orange.opacity(0.07)
        case .thinking: return .blue.opacity(0.10)
        case .runningTool: return .green.opacity(0.10)
        default: return .white.opacity(0.03)
        }
    }

    private var borderColor: Color {
        switch session.state {
        case .waitingApproval: return .yellow.opacity(0.6)
        case .thinking: return .blue.opacity(0.25)
        case .runningTool: return .green.opacity(0.25)
        default: return .clear
        }
    }

    private var tokensText: String {
        guard let tokens = session.metrics?.totalTokens else { return "-- tokens" }
        return tokens >= 1000 ? String(format: "%.1fk tokens", Double(tokens) / 1000)
                              : "\(tokens) tokens"
    }

    /// 时间:运行中显示本轮执行耗时(与收起态一致);非运行显示距最后活动多久
    private var timeText: String {
        if session.state.isActive { return session.turnElapsedText() }
        let seconds = max(0, Int(Date().timeIntervalSince(session.lastActivity)))
        switch seconds {
        case ..<60: return settings.t("just now", "刚刚")
        case ..<3600: return "\(seconds / 60)m"
        default: return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
        }
    }

    private func metric(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.white.opacity(0.1), in: Capsule())
    }
}
