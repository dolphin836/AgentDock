# AgentDock

macOS 刘海扩展应用:实时显示本机 AI Agent(Claude Code / Codex CLI)的会话状态。

- 收起态:刘海下方一排状态点(绿=执行工具、蓝=思考中、黄闪=等待审批、灰=空闲)
- 悬停展开:会话卡片(项目名 / 状态 / 模型 / context% / 成本 / 最近事件)
- Agent 等待审批时面板自动展开 4 秒提醒
- 点击卡片跳转到对应的 iTerm2 / Terminal / VS Code 窗口

## 安装

```bash
./scripts/install.sh
```

交互式完成:语言 / 开机自启 / 三家 Agent 集成 / 系统权限授权,并以 launchd 启动。
开发调试直接 `swift run AgentDock`;无头配置模式 `AgentDock --setup key=value ...`。

## 接入 Agent

安装脚本已含;也可在展开面板 → 设置 tab → 「集成」逐个安装/卸载。

- Claude Code:向 `~/.claude/settings.json` 注册 7 个 hooks + statusLine(原 statusline 输出会被透传;安装前自动备份为 `settings.json.agentdock-backup`,可一键卸载还原)
- Codex:向 `~/.codex/config.toml` 追加 `notify` 行,并后台 tail `~/.codex/sessions` 的 rollout JSONL 推断中间状态

事件通过 `~/.agentdock/agentdock.sock`(NDJSON over Unix socket)进入 App;发射脚本任何失败都静默退出,绝不阻塞 Agent。

## 开发

```bash
swift test                 # 核心逻辑单测
swift run AgentDock &      # 起 App
./scripts/fake-session.sh  # 灌模拟会话验证 UI 全状态流转
```

设计文档见 `docs/superpowers/specs/`,实现计划见 `docs/superpowers/plans/`。
