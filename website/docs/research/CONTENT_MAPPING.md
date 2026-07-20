<!-- [skill: go-team-standards · 内容映射] 将 Vokie 的章节角色改写为经现有 AgentDock 产品事实验证的双语网站文案 -->
# CONTENT MAPPING — Vokie Section Roles → AgentDock Original Content

## Purpose and hard boundary

This is a content blueprint for the existing AgentDock landing page. It preserves the observed **section roles, reading order, and interaction patterns** documented in `PAGE_TOPOLOGY.md` and the component specs, while replacing every Vokie-specific claim, name, visual, and CTA with independently authored AgentDock content.

- Do not reuse Vokie copy, logo, screenshots, illustrations, QR code, favicon, fonts, or URLs.
- Use AgentDock-owned product captures or clearly labelled illustrative UI only; never present a mock value as live account data.
- Keep the English and Simplified Chinese variants semantically equivalent. Brand and agent product names remain in English.
- A section may only claim facts listed in the evidence register below. Where a component spec suggests a capability beyond the available evidence, this document uses the narrower verified wording.

## Verified product-fact register

| ID | Product fact that copy may state | Primary source |
|---|---|---|
| F1 | AgentDock is a macOS notch extension that shows local Claude Code and Codex CLI session status in real time. | `README.md` |
| F2 | The compact notch state uses status dots: running tools, thinking, waiting for approval, and idle. | `README.md` |
| F3 | The expanded panel shows project, status, model, context percentage, cost, and recent event. | `README.md` |
| F4 | An approval waiting state automatically expands the panel for four seconds. | `README.md` |
| F5 | Selecting a session returns to its iTerm2, Terminal, or VS Code window. | `README.md` |
| F6 | Claude Code integration registers seven hooks and a status line, backs up the prior `settings.json`, and can restore it on uninstall. | `README.md` |
| F7 | Codex integration adds a `notify` line and follows local rollout JSONL to infer intermediate state. | `README.md` |
| F8 | Agent events enter the app through a local Unix socket; emitters fail silently so they do not block agents. | `README.md` |
| F9 | The setup flow includes language, launch at login, three-agent integrations, and system permissions. | `README.md` |
| F10 | The site’s current implemented demo and translations present Claude Code, Codex, and Cursor; it demonstrates running, waiting, usage, and return. | `site/index.html`, `site/main.js` |
| F11 | The current site explicitly scopes assisted approval to Codex and Cursor; Claude Code requests are answered through its hook. | `site/index.html`, `site/main.js` |
| F12 | The current site describes local session content, paths, and token details; Apple Events are for workspace return; limited telemetry excludes session content and file paths. | `site/index.html`, `site/main.js` |
| F13 | The current download endpoint and release text are `AgentDock-0.2.4.dmg`, `v0.2.4`, macOS 14+, Universal, Free. | `site/index.html` |

### Fact-resolution rules

1. Prefer F1–F9 when a statement concerns the shipped app described by the repository README.
2. F10–F13 are valid for the current website/demo, but visual demo values such as percentages are examples, not account facts.
3. Do not call AgentDock “fully offline,” “zero-upload,” or “cloud-free.” The available sources support local handling and a limited telemetry boundary, not those absolute claims.
4. Do not state that AgentDock autonomously approves Claude Code requests. The verified boundary is F11.
5. Do not promise that all integrations are reversible in identical ways. The README explicitly documents backup/restore behavior for Claude Code; use precise per-integration language.

## Shared language and CTA policy

| Purpose | English | 简体中文 | Evidence / usage |
|---|---|---|---|
| Main download CTA | Download for Mac | 下载 Mac 版 | F13; use the same DMG URL everywhere. |
| Secondary install CTA | See setup | 查看安装方式 | F9; link to an on-page setup/integrations section, not an invented documentation route. |
| Demo CTA | See the notch | 查看刘海面板 | Existing notch demo in `site/index.html`. |
| Return CTA | Return to workspace | 回到工作区 | F5. |
| Privacy CTA | Read the data boundary | 查看数据边界 | F12; link only if a real privacy page or on-page anchor exists. |
| Download metadata | macOS 14+ · Universal · Free · v0.2.4 | macOS 14+ · 通用版 · 免费 · v0.2.4 | F13. |

The primary download URL is:

`https://api.agentdockstatus.app/v1/download/AgentDock-0.2.4.dmg`

## Section-by-section mapping

### 1. Hero — make the notch experience immediately legible

**Role inherited from the reference:** an uncluttered first impression with a live product stage, a concise value proposition, and an immediate download path.
**AgentDock role:** show a simulated notch panel before explaining it. The stage must use original AgentDock UI, never a Vokie asset or interface.

| Content slot | English | 简体中文 | Fact basis |
|---|---|---|---|
| Eyebrow / tag | AGENTDOCK · FOR CLAUDE CODE, CODEX & CURSOR | AGENTDOCK · 支持 CLAUDE CODE、CODEX 与 CURSOR | F10 |
| H1 line 1 | Every agent in view. | 所有 Agent，都在眼前。 | F1, F10 |
| H1 line 2 | Your focus stays intact. | 你的专注，不被打断。 | Product purpose in `PRODUCT.md` |
| Supporting body | Live status, approvals, and usage in your macOS notch. | 实时状态、审批与用量，都在 macOS 刘海里。 | F1, F10 |
| Stage instruction | Hover, click, or focus the notch to open the live panel. | 悬停、点击或聚焦刘海，展开实时面板。 | Current implementation |
| Primary CTA | Download for Mac | 下载 Mac 版 | F13 |
| Secondary CTA | See the notch | 查看刘海面板 | Current implementation |

**Original stage labels:** `Running / 运行中`, `Needs you / 需要你`, and `Usage / 用量`. The demo can name Claude Code, Codex, and Cursor, but project names, models, and percentages must be fictionalized or marked as examples.

### 2. Value four-panel — explain why a quiet surface matters

**Role inherited from the reference:** a four-part value system that expands on desktop and stacks on smaller screens.
**AgentDock role:** turn the four panels into the four observable outcomes of using a notch-level utility.

| # | English title | English body | 中文标题 | 中文正文 | Fact basis |
|---:|---|---|---|---|---|
| 01 | See the state | Read running, thinking, waiting, and idle without opening each agent window. | 看清状态 | 不用打开每个 Agent 窗口，也能分清运行、思考、等待和空闲。 | F2 |
| 02 | Notice the moment | When attention is needed, the panel opens briefly instead of leaving the request buried in a terminal. | 抓住时机 | 当需要你处理时，面板会短暂展开，不让请求埋在终端里。 | F4 |
| 03 | Check usage | Keep usage in the same entry point, with text labels as well as visual state. | 查看用量 | 在同一个入口查看用量，并同时提供文字标签和视觉状态。 | F10 |
| 04 | Return to work | Select a session to go back to the terminal or editor where it is running. | 回到工作 | 选择一个会话，回到正在运行它的终端或编辑器。 | F5 |

| Shared slot | English | 简体中文 |
|---|---|---|
| Section tag | 01 / FOCUS | 01 / 专注 |
| Section title | Know what needs you, without checking every window. | 不用切遍每个窗口，也知道哪件事需要你。 |
| Section body | One quiet surface for the moments that matter across your local agent work. | 为本地 Agent 工作中真正重要的时刻，留出一个安静的界面。 |
| CTA | See the notch | 查看刘海面板 |

### 3. Three-agent convergence — establish one attention destination

**Role inherited from the reference:** a full-screen transition that turns separate tools into one coherent system.
**AgentDock role:** name the three agent environments without implying identical technical integration mechanisms.

| Content slot | English | 简体中文 | Fact basis |
|---|---|---|---|
| Tag | 02 / ONE ENTRANCE | 02 / 一个入口 | Product purpose |
| Title line 1 | Three kinds of agent. | 三类 Agent。 | F10 |
| Title line 2 | One place to look. | 只看一处。 | F10 |
| Body | Claude Code, Codex, and Cursor each work differently. AgentDock brings their visible state to one entrance in the notch, so your attention has one destination instead of many. | Claude Code、Codex 与 Cursor 各有不同的工作方式。AgentDock 把可见状态汇入刘海里的同一个入口，让你的注意力只有一个去处，而不是许多个。 | F10; product purpose |
| CTA | See live states | 查看实时状态 | F2, F10 |

**Visual content:** use an original animated node field or an original notch-state composition. It may convey convergence, but must not simulate a backend “unified agent runtime,” which is not evidenced.

### 4. Interactive status, approval, usage, and return — demonstrate the working loop

**Role inherited from the reference:** an interactive, tabbed product demonstration where changing the selected item changes the focal UI.
**AgentDock role:** make the four verified surfaces understandable and safe to interact with as a demo.

| Tab / tag | English title | English body | 简体中文标题 | 简体中文正文 | Interaction and fact basis |
|---|---|---|---|---|---|
| 01 / STATUS | Status | See which session is running, thinking, waiting, or idle from the notch. | 状态 | 在刘海里查看哪个会话正在运行、思考、等待或空闲。 | F2 |
| 02 / APPROVAL | Approval | A waiting approval opens the panel briefly. For supported flows, respond from the notch; Claude Code requests are answered through its hook. | 审批 | 等待审批时，面板会短暂展开。对受支持的流程，可在刘海中答复；Claude Code 请求通过其 hook 处理。 | F4, F11 |
| 03 / USAGE | Usage | Read usage in the same place, with text labels that do not rely on color alone. | 用量 | 在同一处读取用量，并用文字标签表达状态，不只依赖颜色。 | F10; `PRODUCT.md` accessibility principle |
| 04 / RETURN | Return | Select the session and go back to its iTerm2, Terminal, or VS Code window. | 返回 | 选择会话，回到对应的 iTerm2、Terminal 或 VS Code 窗口。 | F5 |

| Shared slot | English | 简体中文 |
|---|---|---|
| Section tag | 03 / THE WORKING LOOP | 03 / 工作闭环 |
| Section title | See it. Decide. Return. | 看见、决定、回到现场。 |
| Section body | The notch stays ambient until a session needs attention. Then the next action is close to the status that caused it. | 刘海平时保持在环境中；当会话需要你时，下一步操作就在触发它的状态旁边。 |
| Approval buttons | Allow · Review · Deny | 允许 · 查看 · 拒绝 |
| Initial approval status | Waiting for your decision | 等待你的决定 |
| Usage disclaimer | Example layout — not live account data. | 布局示例，不代表真实账户数据。 |
| CTA | Return to workspace | 回到工作区 |

**Required demo boundary:** the approval controls are an interface demonstration. They must not imply a real approval is being sent from the marketing site, and the Claude Code limitation must remain visible wherever assisted approval is discussed.

### 5. Integrations — explain local, reversible choices precisely

**Role inherited from the reference:** a dark, sequential integration story with durable cards.
**AgentDock role:** explain what AgentDock changes locally, how each tool reports state, and where the documented restore guarantee applies.

| Content slot | English | 简体中文 | Fact basis |
|---|---|---|---|
| Section tag | 04 / INTEGRATIONS | 04 / 集成 |
| Section title | Connect locally. Keep control. | 本地接入，始终可控。 | F8, F9 |
| Section body | Set up integrations from AgentDock, then keep working in the tools you already use. Each integration has its own local mechanism. | 在 AgentDock 中完成集成后，继续使用你原本的工具。每种集成都有各自的本地接入方式。 | F6–F9 |
| Setup CTA | See setup | 查看安装方式 | F9 |
| Claude Code tag | HOOKS + STATUS LINE | HOOKS + 状态栏 | F6 |
| Claude Code body | Registers seven hooks and a status line. Your prior `settings.json` is backed up before installation and can be restored on uninstall. | 注册 7 个 hooks 和状态栏。安装前会备份原有 `settings.json`，卸载时可恢复。 | F6 |
| Codex tag | NOTIFY + LOCAL SESSION LOG | NOTIFY + 本地会话日志 | F7 |
| Codex body | Adds a `notify` entry and follows local rollout JSONL to infer intermediate session state. | 添加 `notify` 配置，并跟随本地 rollout JSONL 推断会话中间状态。 | F7 |
| Event-path tag | LOCAL EVENT PATH | 本地事件路径 | F8 |
| Event-path body | Events enter AgentDock through a local Unix socket. If an emitter fails, it exits quietly and does not block the agent. | 事件通过本地 Unix socket 进入 AgentDock。发射脚本失败时会静默退出，不阻塞 Agent。 | F8 |

**Cursor wording boundary:** the current site demonstrates Cursor hooks, transcript, local storage, usage, and supported assisted approvals (F10–F11), while the README only documents Claude Code and Codex implementation details. Keep Cursor copy to what the current site demonstrably presents; do not invent file names, backup semantics, or protocol details.

### 6. History and context — make local continuity useful, not magical

**Role inherited from the reference:** a lighter product-history moment that shows continuity after an interaction is over.
**AgentDock role:** depict a local session timeline/history view only if that view exists in the supplied product capture. Do not promote it as an AI memory, cloud search, or conversational archive.

| Content slot | English | 简体中文 | Fact basis |
|---|---|---|---|
| Section tag | 05 / SESSION CONTEXT | 05 / 会话上下文 | F3, F10 |
| Title | See the session behind the signal. | 看清状态背后的会话。 | F3 |
| Body | The expanded panel keeps the useful context close: project, status, model, context percentage, cost, and the most recent event. | 展开面板把有用的上下文放在眼前：项目、状态、模型、上下文百分比、成本和最近事件。 | F3 |
| Supporting label | Recent event | 最近事件 | F3 |
| Supporting label | Context | 上下文 | F3 |
| CTA | See the live panel | 查看实时面板 | F3 |

**Content guardrail:** do not use “history” to claim persistent retention duration, cross-device sync, semantic search, or AI recall. Those behaviors are not established by the available sources.

### 7. Privacy — state boundaries, permissions, and telemetry without absolutes

**Role inherited from the reference:** a high-contrast trust section that makes the data boundary unmistakable.
**AgentDock role:** use concrete, source-backed statements rather than a generic “private by design” slogan.

| Content slot | English | 简体中文 | Fact basis |
|---|---|---|---|
| Section tag | 06 / DATA BOUNDARY | 06 / 数据边界 | F12 |
| Title | Your work stays on your Mac. | 你的工作留在你的 Mac 上。 | F12 |
| Intro | Local by default, with clear permission boundaries. | 默认本地处理，权限边界清晰明确。 | F12 |
| Row 1 tag | LOCAL SESSION DATA | 本地会话数据 | F12 |
| Row 1 body | Session content, file paths, and token details stay on your Mac. | 会话内容、文件路径和 token 详情都留在你的 Mac 上。 | F12 |
| Row 2 tag | AUTOMATION | 自动化 | F12 |
| Row 2 body | Apple Events are used only to return you to the correct workspace. | Apple 事件仅用于带你回到正确的工作区。 | F12 |
| Row 3 tag | ACCESSIBILITY | 辅助功能 | F11, F12 |
| Row 3 body | Accessibility assists supported approvals for Codex and Cursor; Claude Code requests are handled through its hook. | 辅助功能协助 Codex 和 Cursor 的受支持审批；Claude Code 请求通过其 hook 处理。 | F11, F12 |
| Row 4 tag | LIMITED TELEMETRY | 有限遥测 | F12 |
| Row 4 body | Telemetry includes launch, version, system, architecture, and crash metadata. It excludes session content and file paths. | 遥测包含启动、版本、系统、架构和崩溃元数据，不包含会话内容和文件路径。 | F12 |
| CTA | Read the data boundary | 查看数据边界 | F12 |

### 8. Final download — finish with a factual, consistent install invitation

**Role inherited from the reference:** a final high-emphasis download card.
**AgentDock role:** close the page with the same release and platform information as the header and hero; do not add unsupported platform claims.

| Content slot | English | 简体中文 | Fact basis |
|---|---|---|---|
| Eyebrow / tag | AGENTDOCK · YOUR AGENTS, WITHIN REACH | AGENTDOCK · 你的 AGENT，随时可见 | Product purpose |
| Title | Put your agents in the notch. | 把你的 Agent 放进刘海。 | F1 |
| Body | Keep live status, approvals, and usage close while you stay in your terminal or editor. | 当你专注于终端或编辑器时，把实时状态、审批和用量放在手边。 | F1, F5, F10 |
| Primary CTA | Download for Mac | 下载 Mac 版 | F13 |
| Secondary CTA | See setup | 查看安装方式 | F9 |
| Platform metadata | macOS 14+ · Universal · Free · v0.2.4 | macOS 14+ · 通用版 · 免费 · v0.2.4 | F13 |

### 9. Footer — retain only useful navigation and verified destinations

**Role inherited from the reference:** a quiet utility footer, not another conversion surface.
**AgentDock role:** provide site navigation, the download, and the copyright line without Vokie-branded assets, unrelated promotion, an admin link, a personal email address, or an invented community channel.

| Content slot | English | 简体中文 | Destination |
|---|---|---|---|
| Brand tagline | Agents work. You stay focused. | Agent 在工作，你保持专注。 | `#top` |
| Nav 1 | Status | 状态 | `#capabilities` or the final stable `#status` anchor |
| Nav 2 | Approval | 审批 | `#journey` or the final stable `#approval` anchor |
| Nav 3 | Usage | 用量 | `#journey` or the final stable `#usage` anchor |
| Nav 4 | Return | 返回工作区 | `#journey` or the final stable `#return` anchor |
| Nav 5 | Integrations | 集成 | `#integrations` |
| Nav 6 | Privacy | 隐私 | `#privacy` |
| Nav 7 | Download for Mac | 下载 Mac 版 | F13 download URL |
| Legal | © 2026 AgentDock | © 2026 AgentDock | Product-owned footer text |

If a public feedback route is not already available, omit the contact column rather than fabricating an address, QR code, Discord invite, or support promise.

## Implementation handoff checklist

- [ ] Preserve the source section order: hero → values → convergence → interactive loop → integrations → session context → privacy → download → footer.
- [ ] Bind all listed copy to the existing English/Chinese i18n mechanism; do not leave one language as an afterthought.
- [ ] Keep the primary download URL and version text identical in header, hero, mobile menu, final CTA, and footer.
- [ ] Label all UI values used only for illustration as examples; remove any real project name, file path, account value, token detail, or other sensitive data from product captures.
- [ ] Keep text labels alongside state colors and maintain the current keyboard-operable notch, approval, menu, and CTA controls.
- [ ] Preserve the Claude Code approval boundary anywhere approval is described.
- [ ] Replace every reference-derived visual asset with an original AgentDock asset before production use.
