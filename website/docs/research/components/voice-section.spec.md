<!-- [skill: go-team-standards · clone-website · 组件取证规格] VoiceSection 精简 wrapper 规格；组合 VoiceTabs 与 VoiceResultStage -->

# VoiceSection Wrapper 组件规格

## Overview
- **准确目标 Next 文件**：`src/components/VoiceSection.tsx`
- **子组件目标**：`src/components/VoiceTabs.tsx`、`src/components/VoiceResultStage.tsx`
- **数据来源**：Chrome DevTools MCP 实测 `https://vokie.com/ #voice`，1440×900 / 768 / 390。
- **职责边界**：本文件只规定 section、标题区、共享状态和子组件布局；5 状态内容/Tab 样式见 `voice-tabs.spec.md`，双卡/打字机见 `voice-result-stage.spec.md`。
- **Interaction model**：wrapper 持有唯一 `activeId`（默认 `filler`）；VoiceTabs 触发更新，VoiceResultStage 消费同一 `VoiceState`；section 另有 scroll-driven reveal。

## Component contract
```text
VoiceSection
├─ voiceStates: VoiceState[5]（单一数据源）
├─ activeId / setActiveId
├─ header + lede
└─ .voice-focus
   ├─ VoiceTabs(items, activeId, onChange)
   └─ VoiceResultStage(state=activeState, reducedMotion)
```
- 不在 wrapper 复制 5 状态文案；数据结构与全部逐字内容以 `voice-tabs.spec.md` 为准。
- tab change 后结果舞台同步 app/icon/before/context/after/status；打字机取消逻辑由 VoiceResultStage 负责。

## DOM
```text
section#voice.voice-section.light-section
├─ div.voice-intro.section-inner
│  ├─ div.section-heading
│  │  ├─ p.eyebrow  “02 / 语音输入”
│  │  └─ h2         “随便说，也能直接用”
│  └─ p.section-lede
│     “在聊天、邮件、文档或 Agent 对话框里按下快捷键。Vokie 整理自然口述，并为你粘贴回输入框。”
└─ div.voice-focus.section-inner[data-reveal]
   ├─ VoiceTabs
   └─ VoiceResultStage
```

## Exact wrapper styles（1440）
### `section#voice`
- `width:1440px; padding:150px 0 170px; background:rgb(218,218,218); color:rgb(9,9,9); overflow:visible`
- computed section height约 `1136.39px`。
- font-family：`MiSans, Geist, Inter, "Noto Sans SC", "PingFang SC", "HarmonyOS Sans SC", "Microsoft YaHei", "OPPO Sans", sans-serif`。

### `.voice-intro`
- `display:grid; grid-template-columns:768px 512px; gap:80px; align-items:end`
- `width:1360px; margin:0 40px 96px`。

### heading / lede
- `.eyebrow`：`12px/15.6px` `"Geist Mono"`，weight 520，uppercase，color `rgb(83,83,83)`，margin-bottom 26px。
- `h2`：`30px/29.4px`，weight 560，color `rgb(9,9,9)`。
- `.section-lede`：`19px/32.3px`，weight 400，color `rgb(83,83,83)`，max-width 520px，padding-bottom 4px。

### `.voice-focus`
- `width:1360px; min-height:620px; margin:0 40px; padding:48px`
- `display:grid; grid-template-columns:413.44px 802.56px; grid-template-rows:524px; gap:48px`
- background `rgb(233,233,231)`；border-radius 32px；position relative。
- 原 DOM 的空 `.focus-frame` 计算 rect 为 0，不需要产出可见节点；grid 直接放两个子组件。

## Reveal trigger / transition
- **Trigger**：section 进入视口（原站 reveal-band / IntersectionObserver）。
- **Before**：`.section-lede` 与 `.voice-focus` `opacity:0; transform:translateY(32px)`。
- **After**：`opacity:1; transform:translateY(0)`。
- **Transition**：`opacity .9s cubic-bezier(.22,1,.36,1), transform .9s cubic-bezier(.22,1,.36,1)`。
- reveal 不改变 active tab，不自动轮播。

## Responsive
| viewport | section / intro | `.voice-focus` | child placement |
|---|---|---|---|
| 1440 | padding `150 0 170`; intro `768/512`, gap 80, margin `0 40 96` | `413.44/802.56`, gap 48, padding 48, radius 32，620高 | Tabs 左，Stage 右（802×520） |
| 768 | intro 单列 720，gap 20，高约248 | 单列 672；rows `80.55px 560px`；gap 48；padding 24；外宽720 | Tabs 上，Stage 下（672×560） |
| 390 | section padding `96px 0`; intro 单列354，gap20，高约195 | 单列306；rows `79px 580px`；gap24；padding `22px 24px`；外宽354，高约727 | 可横滚 Tabs 上，Stage 下（306×580） |
- 布局切换在 ≤768：左右两列 → 上下两行；390 不得水平溢出。

## Reduced motion
- `prefers-reduced-motion:reduce`：wrapper reveal 直接 `opacity:1; transform:none`。
- 全局 transition/animation duration `.01ms!important`、`scroll-behavior:auto`。
- Tabs 仍可选择；ResultStage 直接显示完整输出并停止 caret/typewriter，详见两个子规格。

## Assets / content ownership
- wrapper 无图片、视频或独立图标。
- 5 个 SVG icon、舞台 gradients 归 `VoiceResultStage.tsx`。
- 5 个原站状态与 AgentDock 状态/审批/用量/返回映射归 `VoiceTabs.tsx` 的数据契约；wrapper 只传递。

## AgentDock wrapper 替换
- eyebrow / h2 / lede 可替换为 AgentDock 对应章节文案；整体节奏、light background、标题/演示两层结构保持。
- `voiceStates` 替换为：实时状态、审批提醒、等待输入、用量视图、返回工作区；精确演示内容见 `voice-tabs.spec.md`。
- 结果舞台保留 before/after、状态点和 reduced-motion 行为；禁止真实 PII、密钥或连接串。
