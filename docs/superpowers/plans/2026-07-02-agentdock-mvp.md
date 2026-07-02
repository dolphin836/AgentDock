# AgentDock MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 刘海扩展应用,通过 Unix socket 接收 Claude Code hooks/statusline 与 Codex notify/JSONL 事件,统一状态模型后在刘海胶囊 + 悬停面板中展示。

**Architecture:** 单 SwiftPM 工程:`AgentDockCore` 库(状态模型、事件解析、SessionStore、socket server、适配器安装器,全部可单测)+ `AgentDock` 可执行 App target(AppKit/SwiftUI 刘海窗口)。事件驱动,无持久化。

**Tech Stack:** Swift 6.x, SwiftPM, AppKit + SwiftUI, Darwin Unix domain socket + DispatchSource, swift-testing(`import Testing`)。

## Global Constraints

- macOS 14+,Swift 6 严格并发
- 零第三方依赖
- 发射脚本任何失败必须 `exit 0`,绝不阻塞 Agent
- socket 路径:`~/.agentdock/agentdock.sock`;协议:每行一个 JSON 对象(NDJSON)
- 统一状态:`idle / thinking / runningTool / waitingApproval / done / disconnected`

---

### Task 1: 工程脚手架

**Files:**
- Create: `Package.swift`, `Sources/AgentDockCore/Placeholder.swift`, `Sources/AgentDock/main.swift`, `Tests/AgentDockCoreTests/SmokeTests.swift`, `.gitignore`

**Interfaces:**
- Produces: 可 `swift build` / `swift test` 的工程骨架;库名 `AgentDockCore`,可执行 target `AgentDock`

- [ ] Package.swift:library `AgentDockCore` + executable `AgentDock`(依赖 Core)+ test target
- [ ] `swift test` 通过一个冒烟测试
- [ ] Commit `chore: project scaffold`

### Task 2: 统一状态模型 + 事件映射(核心状态机)

**Files:**
- Create: `Sources/AgentDockCore/Model.swift`, `Sources/AgentDockCore/EventMapping.swift`
- Test: `Tests/AgentDockCoreTests/EventMappingTests.swift`

**Interfaces:**
- Produces:
  - `enum AgentKind: String, Codable, Sendable { case claudeCode = "claude-code", codex }`
  - `enum SessionState: String, Codable, Sendable { case idle, thinking, runningTool, waitingApproval, done, disconnected }`
  - `struct AgentEvent: Sendable { let sessionId: String; let kind: AgentKind; let cwd: String?; let name: String; let detail: String?; let timestamp: Date }`
  - `struct Metrics: Sendable, Equatable { var model: String?; var contextPct: Int?; var costUSD: Double?; var totalTokens: Int? }`
  - `struct AgentSession: Identifiable, Sendable { let id: String; let kind: AgentKind; var projectName: String; var cwd: String; var state: SessionState; var metrics: Metrics?; var recentEvents: [AgentEvent]; var lastActivity: Date }`
  - `func mapEventToState(_ event: AgentEvent, current: SessionState) -> SessionState`

映射表(Claude hooks 事件名):`SessionStart→idle`,`UserPromptSubmit→thinking`,`PreToolUse→runningTool`,`PostToolUse→thinking`,`Notification→waitingApproval`,`Stop→done`,`SessionEnd→done`;Codex:`agent-turn-complete→done`,`task_started→thinking`,`exec_command_begin/tool 调用→runningTool`,`exec_approval_request/apply_patch_approval_request→waitingApproval`,未知事件名 → 保持 current。

- [ ] TDD:先写映射测试(每个事件名一条 + 未知事件保持现状)→ 失败 → 实现 → 通过 → Commit `feat(core): unified state model and event mapping`

### Task 3: 事件解析(EventIngestor)

**Files:**
- Create: `Sources/AgentDockCore/EventIngestor.swift`
- Test: `Tests/AgentDockCoreTests/EventIngestorTests.swift`(内嵌真实样本 JSON fixture)

**Interfaces:**
- Consumes: Task 2 的 `AgentEvent`/`Metrics`
- Produces: `enum IngestResult { case event(AgentEvent), metrics(sessionId: String, Metrics), ignored }`;`func parseLine(_ line: Data) -> IngestResult`

线上协议(发射脚本产出):`{"source":"claude-code"|"codex","type":"hook"|"statusline"|"notify","event":"PreToolUse",...原始负载}`。statusline 负载解析出 model/context/cost。解析失败 → `.ignored`,不 throw 到调用方。

- [ ] TDD:hook 样本、statusline 样本、codex notify 样本、坏 JSON 四组测试 → 实现 → Commit `feat(core): event ingestor with protocol parsing`

### Task 4: SessionStore

**Files:**
- Create: `Sources/AgentDockCore/SessionStore.swift`
- Test: `Tests/AgentDockCoreTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: Task 2/3 类型
- Produces: `@MainActor @Observable final class SessionStore { var sessions: [AgentSession]; func apply(_ result: IngestResult); func prune(now: Date) }`

规则:新 sessionId 自动建会话;`recentEvents` 保留 20 条;`prune`:>30min 无活动 → disconnected,>2h → 移除。`apply` 后按 lastActivity 倒序。

- [ ] TDD:建会话/状态流转/环形缓冲/prune 四组测试 → 实现 → Commit `feat(core): session store`

### Task 5: Unix socket server

**Files:**
- Create: `Sources/AgentDockCore/SocketServer.swift`
- Test: `Tests/AgentDockCoreTests/SocketServerTests.swift`(真实 socket 集成测试:起 server,`nc -U` 式客户端写行,断言回调)

**Interfaces:**
- Produces: `final class SocketServer: @unchecked Sendable { init(path: String, onLine: @escaping @Sendable (Data) -> Void); func start() throws; func stop() }`

Darwin `socket(AF_UNIX, SOCK_STREAM)` + `DispatchSource.makeReadSource`;启动前删除残留 socket 文件;按 `\n` 分帧;单连接错误不影响 server。

- [ ] TDD:写一行收一行、多行分帧、坏连接不崩 → 实现 → Commit `feat(core): unix socket server`

### Task 6: 发射脚本 + Claude Code 安装器

**Files:**
- Create: `Sources/AgentDockCore/Resources/agentdock-emit`(bash), `Sources/AgentDockCore/ClaudeInstaller.swift`
- Test: `Tests/AgentDockCoreTests/ClaudeInstallerTests.swift`(临时目录中的 settings.json 读写)

**Interfaces:**
- Produces: `struct ClaudeInstaller { init(settingsPath: String, emitPath: String); func install() throws; func uninstall() throws; var isInstalled: Bool }`

`agentdock-emit`:stdin 读 JSON,包一层 `{"source":$1,"type":$2,...}` 后 `nc -U ~/.agentdock/agentdock.sock`;任何失败 `exit 0`。statusline 模式下若存在用户原 statusline(安装时备份其命令到 wrapper),先透传原输出。安装器:备份 `settings.json` 为 `.agentdock-backup`,merge 写入 7 个 hooks + statusLine;卸载恢复。

- [ ] TDD:安装(空配置/已有 hooks 合并)、卸载还原、幂等 → 实现 → 脚本手测 `echo '{}' | agentdock-emit claude-code hook` → Commit `feat: emit script and claude installer`

### Task 7: Codex 适配器(notify 安装 + JSONL tail)

**Files:**
- Create: `Sources/AgentDockCore/CodexInstaller.swift`, `Sources/AgentDockCore/CodexSessionTailer.swift`
- Test: `Tests/AgentDockCoreTests/CodexTests.swift`

**Interfaces:**
- Produces: `struct CodexInstaller { func install() throws; func uninstall() throws }`(config.toml 文本级 merge `notify` 行);`final class CodexSessionTailer { init(root: String, onLine: @escaping @Sendable (Data) -> Void); func start(); func stop() }`

Tailer:DispatchSource 监控 `~/.codex/sessions` 目录树,新文件/追加行回调;行透传给 EventIngestor(其 codex 分支解析 rollout JSON:`type` 字段映射事件)。解析不了的行 ignored。

- [ ] TDD:tail 追加行、config merge/还原 → 实现 → Commit `feat: codex adapter`

### Task 8: 刘海 UI(收起胶囊 + 悬停面板)

**Files:**
- Create: `Sources/AgentDock/AppDelegate.swift`, `Sources/AgentDock/NotchWindow.swift`, `Sources/AgentDock/CapsuleView.swift`, `Sources/AgentDock/PanelView.swift`, `Sources/AgentDock/SessionCardView.swift`, `Sources/AgentDock/TerminalJumper.swift`; Modify: `Sources/AgentDock/main.swift`

**Interfaces:**
- Consumes: `SessionStore`(环境注入)、`SocketServer`、`EventIngestor`

要点:借 `NSScreen.safeAreaInsets`/`auxiliaryTopLeftArea` 定位刘海;无刘海屏顶部居中。`NSPanel`(nonactivating, `.statusBar` level, ignoresMouseEvents 按需)承载 SwiftUI。收起态:状态点行(色映射 绿/蓝/黄闪/灰);hover(NSTrackingArea)→ 展开面板(会话卡片:图标+项目名+状态+指标+最近3事件);waitingApproval → 自动展开 4s + 脉冲。点击卡片 → TerminalJumper 用 AppleScript 依次尝试 iTerm2/Terminal/VS Code 按 cwd 匹配窗口,失败复制路径。每 60s 定时 `store.prune`。

- [ ] 实现窗口定位+收起态 → 手测
- [ ] 实现展开面板+自动提醒+跳转 → 手测
- [ ] Commit `feat(app): notch UI`

### Task 9: 集成与端到端验证

**Files:**
- Create: `README.md`, `scripts/fake-session.sh`(向 socket 灌模拟事件)

- [ ] `swift test` 全绿;`swift run AgentDock` + `fake-session.sh` 验证:建会话→thinking→runningTool→waitingApproval(自动展开)→done
- [ ] 真实 Claude Code 会话验证 hooks/statusline
- [ ] Commit `feat: e2e integration`

## Self-Review

- 覆盖 spec §2-§7 全部要求;「一键批准」明确不做,与 spec 一致。
- 类型签名跨任务一致(AgentEvent/IngestResult/SessionStore.apply)。
- 无 TBD/占位。
