# AgentDock 设计文档

日期:2026-07-02
状态:已确认

## 1. 目标

一个 macOS 刘海扩展应用,实时展示本机主流 AI Agent(MVP 支持 Claude Code 与 Codex CLI)的会话状态。平时收起为刘海两侧的状态点,悬停展开面板查看会话详情;当 Agent 进入「等待审批」状态时自动展开提醒。

## 2. 总体架构(方案 A:单 App + 内置 Unix socket)

```
Claude Code hooks/statusline 脚本 ─┐
Codex notify 脚本 ────────────────┼─→ Unix socket (~/.agentdock/agentdock.sock)
Codex sessions JSONL tail ────────┘          │
                                    EventIngestor(解析、去重)
                                             │
                                    SessionStore(内存态,@Observable)
                                             │
                              ┌──────────────┴──────────────┐
                        NotchWindow(收起态胶囊)      ExpandedPanel(悬停展开)
```

- 单 Target macOS App,SwiftUI + AppKit,`LSUIElement = true`(无 Dock 图标),Swift 6 并发。
- App 启动即监听 Unix domain socket;App 未运行时事件丢失可接受(不显示也不需要数据)。
- 代码结构:SwiftPM 包 `AgentDockCore`(纯逻辑,可单测)+ App target(UI)。

## 3. 统一状态模型

```swift
enum AgentKind { case claudeCode, codex }
enum SessionState { case idle, thinking, runningTool, waitingApproval, done, disconnected }

struct AgentSession {
    let id: String            // Claude session_id / Codex thread id
    let kind: AgentKind
    var projectName: String   // cwd 最后一段
    var cwd: String
    var state: SessionState
    var metrics: Metrics?     // model, tokens, contextPct, cost(仅 Claude)
    var recentEvents: [AgentEvent]  // 环形缓冲,保留最近 20 条
    var lastActivity: Date
}
```

- 各 Agent 原生事件统一映射到 `SessionState`,UI 层不感知底层差异。
- 超过 30 分钟无事件 → `disconnected`;2 小时后从列表移除。

## 4. 采集层

### 4.1 Claude Code 适配器

- App 内「一键安装」将发射脚本 `agentdock-emit`(随 App 附带)注册进 `~/.claude/settings.json` 的 hooks:
  `SessionStart`、`UserPromptSubmit`(→ thinking)、`PreToolUse`(→ runningTool)、`PostToolUse`、`Notification`(→ waitingApproval)、`Stop`(→ done)、`SessionEnd`。
- statusline 命令同样打到 socket,提供 model / token 用量 / context 占比 / cost 指标;若用户已有 statusline 配置则包装并原样透传其输出,未配置则输出 AgentDock 简版。
- 安装前备份 `settings.json`,提供一键卸载恢复。

### 4.2 Codex 适配器

- `~/.codex/config.toml` 写入 `notify = ["agentdock-emit", "codex"]`,获取回合结束事件。
- 后台 `DispatchSource` 监控 `~/.codex/sessions/**/*.jsonl` 新增行,解析事件推断 thinking / runningTool / waitingApproval 中间状态。
- 解析失败时降级为「运行中/结束」两态,绝不崩溃。

## 5. UI 层

- **收起态**:刘海两侧紧贴的小胶囊,每个活跃会话一个状态点(绿=运行、蓝=thinking、黄=等待审批且闪烁、灰=idle);无会话时完全隐形。
- **展开态**:悬停刘海区域向下展开黑色圆角面板(与刘海视觉融合),会话卡片包含:Agent 图标 + 项目名 + 状态 + 指标行(model / context% / cost)+ 最近 3 条事件。
- **点击跳转**:点击卡片按 cwd 匹配激活对应终端窗口(iTerm2 / Terminal / VS Code,经 Accessibility/AppleScript);匹配不到则复制路径。
- **提醒策略**:进入 waitingApproval 时面板自动展开 4 秒 + 黄点脉冲动画;不发系统通知。
- **无刘海屏**:外接显示器上退化为顶部居中悬浮胶囊,交互一致。
- 明确不做:「一键批准」(跨进程注入按键有安全与可靠性问题,跳转终端已覆盖主要场景)。

## 6. 错误处理

- socket 消息全部为 JSON;解析失败丢弃并记 log,不 crash。
- 发射脚本在 App 未运行(socket 连接失败)时静默 `exit 0`,绝不阻塞 Agent 本身 —— 硬约束。
- 采集适配器对上游格式变更以降级(减少状态精度)方式容错。

## 7. 测试

- 单元测试:事件 JSON → 统一状态机映射(核心);hooks/notify/JSONL 协议解析用真实样本 fixture。
- UI(窗口定位、悬停展开、动画)手动验证。
