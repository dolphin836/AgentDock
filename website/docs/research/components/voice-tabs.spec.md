<!-- [skill: go-team-standards · clone-website · 组件取证规格] VoiceTabs 五状态与交互规格；数值实测自 https://vokie.com/ #voice -->

# VoiceTabs 组件规格

## Overview
- **准确目标 Next 文件**：`src/components/VoiceTabs.tsx`
- **父组件**：`src/components/VoiceSection.tsx`
- **兄弟组件**：`src/components/VoiceResultStage.tsx`
- **Interaction model**：click-driven single-select tabs；原生 `<button>` 支持 Enter/Space。默认 `filler`，点击后由父层共享 active key 给结果舞台。
- **数据来源**：Chrome DevTools MCP，1440/768/390 的 `getComputedStyle` 与 5 次实际点击；不得估计。

## Props / state contract
- `items: VoiceState[]`：下表 5 项完整数据。
- `activeId: VoiceStateId`；`onChange(id)`。
- 每个按钮：`id="voice-tab-{id}"`、`aria-selected`、`aria-controls="voice-result-stage"`；建议容器 `role="tablist"`、按钮 `role="tab"`。
- `VoiceStateId = "filler" | "correction" | "paragraphs" | "lists" | "words"`。
- `VoiceState` 至少含 `id,title,subtitle,appName,context,before,after,iconId`；同一数据对象同时驱动 `VoiceResultStage`，避免两份状态内容漂移。

## DOM
```text
div.focus-list[role=tablist]
└─ button.focus-item[.is-active]#voice-tab-{id}[role=tab] ×5
   ├─ span.focus-item-title
   └─ small
```

## Exact styles（1440）
### `.focus-list`
- `display:flex; flex-direction:column; justify-content:center; gap:6px; position:relative; z-index:2`
- computed rect：`413.44 × 524px`。

### `.focus-item` 非激活
- `width:413.44px; min-height:96px; padding:16px 18px 15px 22px`
- `background:rgb(255,255,255); border:0; border-radius:16px`
- `box-shadow:none; transform:none; cursor:pointer`
- `transition: opacity .24s, transform .36s cubic-bezier(.22,1,.36,1), background-color .24s, border-color .24s, box-shadow .24s`

### `.focus-item.is-active`
- 与非激活态相同尺寸/颜色；仅变为 `transform:translateX(8px)`。
- `box-shadow:rgba(24,27,28,.05) 0 7px 18px`。

### 文本
- `.focus-item-title`：`20px/21.6px`，weight 560，color `rgb(17,17,17)`，display block，padding-right 34px。
- `small`：`12px/18.6px`，weight 400，color `rgb(83,83,83)`，opacity `.62`，margin-top 8px，max-width 260px。

## Trigger / states / transition
- **Trigger**：click、Enter 或 Space。
- **Before**：旧项 `.is-active`、`translateX(8px)`、有投影。
- **After**：新项获得该状态；旧项回 `transform:none; box-shadow:none`。
- **Transition**：位移 `.36s cubic-bezier(.22,1,.36,1)`；投影 `.24s`。
- 点击还必须调用 `onChange(id)`，由结果舞台同步 app 名、icon、before、context、after 与打字机状态；Tabs 自身不实现打字机。
- 未观察到自动轮播、hover 专属属性变化或 scroll-driven 自动切 tab。

## 5 states（逐字实测，不得删改）
| id | title | subtitle | appName | context | before | after | iconId |
|---|---|---|---|---|---|---|---|
| filler | 去掉口癖 | 删掉“嗯、那个”，保留真正想说的。 | 去掉口癖 | 发给小林 | 嗯那个，小林，活动页面我看过了，然后就是移动端也没什么问题。 | 小林，活动页面和移动端适配都已确认。 | `#voice-icon-filler` |
| correction | 接住改口 | 识别临时修正，只留下最后决定。 | 接住改口 | 主题：活动页面确认 | 明天下午三点，不对，四点跟小林对一下活动页面。 | 明天下午 4 点与小林确认活动页面。 | `#voice-icon-correction` |
| paragraphs | 自动分段 | 根据语义停顿，整理出清晰段落。 | 自动分段 | 产品发布复盘 | 上午先确认发布范围和负责人。下午再看用户反馈，重点整理语音输入和会议记录的问题，最后把结论发给团队。 | 上午确认发布范围与负责人。`\\n\\n`下午整理用户对语音输入和会议记录的反馈，并将结论同步给团队。 | `#voice-icon-paragraphs` |
| lists | 整理成列表 | 把连续交代拆成一眼可读的事项。 | 整理成列表 | 发布前检查 | 发布前要核对首屏文案，检查报名流程，再把移动端适配过一遍。 | 发布前检查：`\\n· 首屏文案\\n· 报名流程\\n· 移动端适配` | `#voice-icon-lists` |
| words | 记住专有词 | 改正一次，下次准确写出名称。 | 记住专有词 | 新对话 | 下次跟 Vokia 团队确认拾忆和 Codex 的连接。 | 下次与 Vokie 团队确认“拾忆”和 Codex 的连接。 | `#voice-icon-words` |

## Responsive
- **1440**：纵排，413.44px 宽，5 项各 96px，gap 6。
- **768**：横排，容器 `672 × 80.55px`，gap 6；置于结果舞台上方。
- **390**：横排且 `overflow-x:auto`，容器 `306 × 79px`；item 宽约 154px、min-height 64px、padding `12px 16px`，允许横向滚动查看 5 项。
- wrapper 在 ≤768 由左右两列切为上下两行；Tabs 不自行决定 wrapper grid。

## Reduced motion
- 全局规则：`transition-duration:.01ms!important; animation-duration:.01ms!important`。
- 仍切换选中态与 ARIA，但位移/投影近乎瞬时；不得禁用点击和键盘行为。

## Assets
- 只引用 5 个 icon id；SVG symbol/React icon 的视觉实现归 `VoiceResultStage.tsx`。
- 无图片/视频；正文 `MiSans` 回退链，等宽字体不在 Tabs 使用。

## AgentDock 替换数据
| tab | subtitle / result intent | status path | context |
|---|---|---|---|
| 实时状态 | 三个分散终端 → 刘海统一运行/等待/空闲 | 正在同步 → 已统一 | 刘海总览 |
| 审批提醒 | Codex 写入请求 → Allow / Review / Deny | 待审批 → 已响应 | 权限请求 |
| 等待输入 | Agent 阻塞 → 刘海直接回复 | 等待中 → 已回复 | 阻塞提醒 |
| 用量视图 | 分散用量 → 同一入口汇总 | 汇总中 → 已汇总 | 用量总览 |
| 返回工作区 | 会话难定位 → 跳回终端/编辑器 | 定位中 → 已跳转 | 会话回跳 |
- 以上为演示 mock，不放真实 PII、密钥或连接串。
