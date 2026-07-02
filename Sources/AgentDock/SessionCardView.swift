import SwiftUI
import AppKit
import AgentDockCore

/// 会话所属终端 App 的图标(尽力猜测:取正在运行的常见终端/编辑器)
@MainActor
enum TerminalAppIcon {
    private static var cached: NSImage?
    private static let bundleIds = [
        "com.mitchellh.ghostty", "com.googlecode.iterm2",
        "com.apple.Terminal", "com.microsoft.VSCode",
    ]

    static var icon: NSImage? {
        if let cached { return cached }
        for id in bundleIds {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                cached = app.icon
                return cached
            }
        }
        return nil
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
                    if let appIcon = TerminalAppIcon.icon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                }
                // 第二行:模型 / ctx% / 费用
                if let m = session.metrics {
                    HStack(spacing: 8) {
                        if let model = m.model { metric(model) }
                        if let pct = m.contextPct { metric("ctx \(pct)%") }
                        if let cost = m.costUSD { metric(String(format: "$%.2f", cost)) }
                    }
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

    private func metric(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.white.opacity(0.1), in: Capsule())
    }
}
