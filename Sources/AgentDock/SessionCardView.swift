import SwiftUI
import AppKit
import AgentDockCore

/// 会话宿主 App 图标:用发射脚本沿父进程链探测到的 .app 路径精确取图标,带缓存
@MainActor
enum HostAppIcon {
    private static var cache: [String: NSImage] = [:]

    static func icon(forAppPath path: String?) -> NSImage? {
        guard let path, !path.isEmpty else { return nil }
        if let hit = cache[path] { return hit }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache[path] = image
        return image
    }
}

struct SessionCardView: View {
    let session: AgentSession
    let settings: AppSettings
    @State private var hovered = false

    var body: some View {
        Button {
            TerminalJumper.jump(toCwd: session.cwd)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                // 第一行:与收起态一致 + 末尾 app 图标
                HStack(spacing: 6) {
                    AgentIcon(kind: session.kind, spinning: session.state.isActive, size: 12)
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let text = session.latestText {
                        Text(text)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 8)
                    Text(settings.label(for: session.state))
                        .font(.system(size: 11))
                        .foregroundStyle(session.state.dotColor)
                    StatusDot(state: session.state)
                    if let appIcon = HostAppIcon.icon(forAppPath: session.appPath) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
                // 第二行:模型 / ctx / token 消耗 / 时间(缺失的字段用 -- 占位)
                HStack(spacing: 8) {
                    metric(session.metrics?.model ?? "--")
                    metric("ctx \(session.metrics?.contextPct.map { "\($0)%" } ?? "--")")
                    metric(tokensText)
                    metric(relativeTime)
                }
            }
            .padding(10)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: session.state == .waitingApproval ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    /// 状态区分:hover 最亮 > 需要审批(黄) > 等待输入(橙) > 进行中 > 其他调暗
    private var cardBackground: Color {
        if hovered { return .white.opacity(0.16) }
        switch session.state {
        case .waitingApproval: return .yellow.opacity(0.10)
        case .waitingInput: return .orange.opacity(0.08)
        case .thinking, .runningTool: return .white.opacity(0.07)
        default: return .white.opacity(0.04)
        }
    }

    private var borderColor: Color {
        session.state == .waitingApproval ? .yellow.opacity(0.6) : .clear
    }

    private var tokensText: String {
        guard let tokens = session.metrics?.totalTokens else { return "-- tokens" }
        return tokens >= 1000 ? String(format: "%.1fk tokens", Double(tokens) / 1000)
                              : "\(tokens) tokens"
    }

    /// 最后活动的相对时间:刚刚 / 5m / 1h 12m
    private var relativeTime: String {
        let seconds = max(0, Int(Date().timeIntervalSince(session.lastActivity)))
        switch seconds {
        case ..<60: return settings.t("now", "刚刚")
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
