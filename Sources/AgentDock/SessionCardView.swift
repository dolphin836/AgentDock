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
    /// 待审批请求(有则显示 Yes/No 按钮)及决策回调
    var approval: SessionStore.PendingApproval?
    var onDecision: ((UUID, Bool) -> Void)?
    @State private var hovered = false

    private var running: Bool {
        session.state == .thinking || session.state == .runningTool
    }

    var body: some View {
        Button {
            TerminalJumper.jump(toCwd: session.cwd, appPath: session.appPath, kind: session.kind)
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
                    .font(Theme.mono(12.5, .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Text(session.activityLabel(settings: settings))
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(session.state.dotColor)
                    StatusGlyph(state: session.state)
                }
                .breathing(running)
                Image(nsImage: HostAppIcon.icon(
                    forAppPath: session.appPath ?? session.kind.fallbackAppPath))
                    .resizable()
                    .frame(width: 15, height: 15)
                    .grayscale(0.35)
                    .opacity(0.9)
            }
            Text(metricsLine)
                .font(Theme.mono(9.5))
                .foregroundStyle(Theme.text3)
                .lineLimit(1)
                .padding(.leading, 21)  // 与名称对齐

            // 待审批:请求内容 + Yes/No。Claude 走 hook 阻塞真代答;
            // Codex/Cursor 走辅助代答(聚焦宿主 + 合成审批按键)
            if let approval {
                HStack(spacing: 8) {
                    Text([approval.toolName, approval.detail].compactMap(\.self).joined(separator: ": "))
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.yellow.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    approvalButton(settings.t("ALLOW", "允许"), color: Theme.phosphor) {
                        onDecision?(approval.id, true)
                    }
                    approvalButton(settings.t("DENY", "拒绝"), color: Theme.red) {
                        onDecision?(approval.id, false)
                    }
                }
                .padding(.leading, 21)
                .padding(.top, 2)
            } else if session.state == .waitingApproval, AssistedApproval.supports(session.kind) {
                HStack(spacing: 8) {
                    Text(approvalDetail ?? settings.t("approval requested", "请求审批"))
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.yellow.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    approvalButton(settings.t("ALLOW", "允许"), color: Theme.phosphor) {
                        AssistedApproval.respond(session: session, allow: true)
                    }
                    approvalButton(settings.t("DENY", "拒绝"), color: Theme.red) {
                        AssistedApproval.respond(session: session, allow: false)
                    }
                }
                .padding(.leading, 21)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) {
            // 左缘状态色条:扫视时快速定位「谁在等我」
            RoundedRectangle(cornerRadius: 1)
                .fill(session.state.dotColor.opacity(edgeOpacity))
                .frame(width: 2)
                .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
    }

    // MARK: 单行(历史)

    private var compactRow: some View {
        HStack(spacing: 7) {
            AgentIcon(kind: session.kind, spinning: false, size: 10)
                .frame(width: 14)
                .opacity(0.5)
            Text(session.projectName)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
            if let model = session.metrics?.model {
                Text(model)
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.text4)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(recentStateText)
                .font(Theme.mono(9.5))
                .foregroundStyle(recentStateColor)
            Text(timeText)
                .font(Theme.mono(9.5))
                .foregroundStyle(Theme.text3)
            Text(recentStateGlyph)
                .font(Theme.mono(9))
                .foregroundStyle(recentStateColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .background(hovered ? Color.white.opacity(0.06) : .clear,
                    in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
    }

    // MARK: 状态文案

    /// RECENT 行的状态文案:回合已结束(done)的会话对用户而言是「等待输入」;
    /// 其余(空闲/断开)按原状态显示,整体压暗不与上方分组抢视觉
    private var recentStateText: String {
        session.state == .done
            ? settings.t("Waiting for input", "等待输入")
            : settings.label(for: session.state)
    }

    private var recentStateGlyph: String {
        session.state == .done ? SessionState.waitingInput.glyph : session.state.glyph
    }

    private var recentStateColor: Color {
        session.state == .done
            ? Theme.amber.opacity(0.55)
            : session.state.dotColor.opacity(0.7)
    }
}

extension AgentSession {
    /// 状态文案,运行中细分到具体动作(检索/编辑/命令/子任务/MCP),
    /// 等待输入时若是 agent 主动提问则显示「向你提问」
    @MainActor
    func activityLabel(settings: AppSettings) -> String {
        if state == .runningTool, let category = currentToolCategory {
            switch category {
            case .search: return settings.t("Reading…", "检索中…")
            case .edit: return settings.t("Editing…", "编辑中…")
            case .shell: return settings.t("Running cmd…", "命令执行中…")
            case .verify: return settings.t("Verifying…", "验证中…")
            case .subtask: return settings.t("Subagent…", "子任务中…")
            case .mcp: return settings.t("MCP call…", "MCP 调用中…")
            }
        }
        if state == .waitingInput,
           let tool = recentEvents.last?.tool, isUserFacingTool(tool) {
            return settings.t("Asking you", "向你提问")
        }
        return settings.label(for: state)
    }

    private enum ToolCategory { case search, edit, shell, verify, subtask, mcp }

    private var currentToolCategory: ToolCategory? {
        // 最近一条工具开始事件:cursor/claude 带工具名,codex 新版是 function_call 系列
        for event in recentEvents.reversed() {
            switch event.name {
            case "PreToolUse", "preToolUse", "function_call", "custom_tool_call",
                 "web_search_call", "tool_search_call":
                guard let tool = event.tool else { return nil }
                return Self.category(forTool: tool, detail: event.detail)
            case "exec_command_begin": return Self.shellCategory(command: event.detail)
            case "patch_apply_begin": return .edit
            case "mcp_tool_call_begin": return .mcp
            default: continue
            }
        }
        return nil
    }

    private static func category(forTool tool: String, detail: String?) -> ToolCategory? {
        switch tool {
        case "Read", "Grep", "Glob", "LS", "SemanticSearch", "codebase_search",
             "WebSearch", "WebFetch", "NotebookRead", "view_image",
             "web_search_call", "tool_search_call":
            return .search
        case "Write", "Edit", "MultiEdit", "StrReplace", "Delete", "EditNotebook",
             "NotebookEdit", "search_replace", "apply_patch":
            return .edit
        case "Bash", "Shell", "run_terminal_cmd", "exec_command":
            return shellCategory(command: detail)
        case "BashOutput", "AwaitShell", "write_stdin":
            return .shell
        case "Task", "Agent", "task_v2":
            return .subtask
        case "CallMcpTool", "FetchMcpResource", "ListMcpResources":
            return .mcp
        default:
            return tool.hasPrefix("mcp_") ? .mcp : nil
        }
    }

    /// shell 命令按内容细分:只读检索类 → 检索;测试/构建类 → 验证;其余 → 命令
    private static func shellCategory(command: String?) -> ToolCategory {
        guard let command, !command.isEmpty else { return .shell }
        let first = command.split(separator: " ").first.map(String.init) ?? ""
        if ["rg", "grep", "cat", "ls", "find", "fd", "head", "tail", "tree",
            "wc", "stat", "file", "which", "man"].contains(first) {
            return .search
        }
        let verifyMarkers = ["swift test", "npm test", "pnpm test", "yarn test", "go test",
                             "pytest", "cargo test", "swift build", "npm run build",
                             "cargo build", "go build", "lint", "tsc ", "go vet"]
        if verifyMarkers.contains(where: { command.contains($0) }) { return .verify }
        return .shell
    }
}

private extension SessionRowView {
    // MARK: 组件

    func approvalButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(9.5, .bold))
                .tracking(0.5)
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 审批请求的内容(命令/拦截原因),取最近一条审批事件
    var approvalDetail: String? {
        let approvalEvents: Set<String> = ["approvalRequest", "exec_approval_request",
                                           "apply_patch_approval_request", "elicitation_request"]
        return session.recentEvents.last { approvalEvents.contains($0.name) }?.detail
    }

    /// 任务名字色:运行中/等你跟随状态色,其余白
    private var nameColor: Color {
        switch session.state {
        case .thinking, .runningTool, .waitingApproval, .waitingInput:
            session.state.dotColor
        default:
            Theme.text1
        }
    }

    /// 等你的行有轻微暖色底;进行中靠光标动效;hover 提亮
    private var rowBackground: Color {
        if hovered { return .white.opacity(0.08) }
        switch session.state {
        case .waitingApproval: return Theme.yellow.opacity(0.07)
        case .waitingInput: return Theme.amber.opacity(0.05)
        default: return .clear
        }
    }

    /// 左缘色条透明度:等你 > 进行中 > 其他
    private var edgeOpacity: Double {
        switch session.state {
        case .waitingApproval, .waitingInput: 0.9
        case .thinking, .runningTool: 0.6
        default: 0
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
