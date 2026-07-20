<!-- [skill: go-team-standards · clone-website · 组件取证规格] VoiceResultStage 双卡、五状态同步与打字机规格；数值实测自 https://vokie.com/ #voice -->

# VoiceResultStage 组件规格

## Overview
- **准确目标 Next 文件**：`src/components/VoiceResultStage.tsx`
- **父组件**：`src/components/VoiceSection.tsx`
- **状态数据源**：`VoiceTabs.tsx` 规格定义的同一个 `VoiceState`；本组件接收 `state` 与 `reducedMotion`，不得复制或改写 5 组内容。
- **Interaction model**：由 tab change 驱动的状态切换 + JS typewriter；固定文案 `你说的`、`VOKIE 输出`，状态 `Vokie 整理中` → `Vokie 已整理`。

## DOM
```text
div.voice-result-stage#voice-result-stage[role=tabpanel]
├─ svg[hidden]
│  └─ symbol#voice-icon-{filler|correction|paragraphs|lists|words} ×5
├─ div.voice-app-bar
│  ├─ div.voice-app-identity
│  │  ├─ span.voice-app-icon > svg > use[href=state.iconId]
│  │  └─ span[data-voice-app-name]
│  └─ div.voice-stage-status
│     ├─ span.voice-stage-status-dot
│     └─ span[data-voice-status]
└─ div.voice-editor
   ├─ div.result-before
   │  ├─ span.proof-label  “你说的”
   │  └─ p
   ├─ div.result-after
   │  ├─ div.voice-editor-meta
   │  │  ├─ span.proof-label “VOKIE 输出”
   │  │  └─ span[data-voice-app-context]
   │  ├─ div.voice-output[data-voice-output]
   │  └─ span.voice-editor-caret[aria-hidden]
   └─ div.voice-capture-layer
```

## Exact styles（1440）
### `.voice-result-stage`
- computed `802.56 × 520px`；`min-height:520px; display:flex; flex-direction:column; position:relative; overflow:hidden; border-radius:22px`
- background-color `rgb(16,17,18)`。
- 两层 background-image：
  1. `radial-gradient(circle, rgba(255,255,255,.12) 1px, transparent 1.2px)`，size `28px 28px`；
  2. `radial-gradient(circle at 50% 38%, rgba(255,255,255,.035), transparent 44%)`。

### `.voice-app-bar`
- `height:62px; padding:0 22px; display:flex; justify-content:space-between; align-items:center; position:relative; z-index:2`
- background `rgba(16,17,18,.76)`；border-bottom `1px solid rgba(255,255,255,.1)`。
- `.voice-app-identity`：`13px/19.5px`，weight 600，color `rgba(255,255,255,.92)`，flex align-center，gap 10px。
- `.voice-stage-status`：`11px/16.5px` `"Geist Mono"`，weight 520，color `rgba(255,255,255,.58)`，flex align-center，gap 7px。

### `.voice-editor`
- `height:458px; padding:30px 40px 104px; position:relative`。
- `.result-before`：width 590px；background `rgb(255,255,255)`；color `rgb(83,83,83)`；padding `18px 22px 20px`；margin `12px 66.28px -30px`；border-radius 22px；box-shadow `rgba(0,0,0,.18) 0 14px 32px`；position relative；z-index 3。
- `.result-after`：width 650px；height 210px；background `rgba(246,246,252,.98)`；padding `58px 28px 30px`；margin `0 36.28px`；border-radius 22px；box-shadow `rgba(0,0,0,.16) 0 18px 38px`；position relative；z-index 1。
- `.proof-label`：`9px/11.7px` `"Geist Mono"`，weight 520，uppercase，color `rgba(17,17,17,.48)`，margin-bottom 6px。
- `.voice-editor-meta`：`11px/16.5px` `"Geist Mono"`，color `rgba(17,17,17,.46)`，flex space-between，align-items baseline，gap 18px，margin-bottom 20px。
- `.voice-output`：`19px/30.02px`，weight 440，color `rgb(9,9,9)`，`white-space:pre-line`。
- `.voice-editor-caret`：inline-block，`2 × 18.4px`，background `rgb(37,99,235)`，margin-left 3px；打字时 opacity 闪烁。

## State synchronization（5 项内容不可丢）
- 完整逐字数据以 `voice-tabs.spec.md` 的 **5 states** 表为唯一来源：filler / correction / paragraphs / lists / words，包含 appName、context、before、after、iconId。
- 每次 `state.id` 改变必须同步：
  1. `<use href>` = `state.iconId`，app name = `state.appName`；
  2. before `<p>` 立即显示 `state.before`；
  3. context 显示 `state.context`；
  4. output 清空后逐字写入 `state.after`，保留 paragraphs 的空行和 lists 的 `·` 列表；
  5. status 先 `Vokie 整理中`，完成后 `Vokie 已整理`。
- 快速连续切 tab：取消上一轮 timer/RAF，旧字符不得继续写入新状态；卸载时清理 timer。

## Typewriter trigger / transition
- **Trigger**：父组件传入的新 `state.id`。
- **State A**：status=`整理中`，output 从空串开始，caret 可见/闪烁。
- **State B**：全文写完，status=`已整理`，caret 隐藏或 opacity 0。
- **Mechanism**：JS 逐 Unicode 字符推进（不能按 UTF-16 code unit 截断中文/emoji）；原站为 JS typewriter，非 CSS transition。
- 原站实测点击后中途可见截断文本，约 2.6s 后长文本完成；实现应按统一字符间隔并以全文长度决定总时长。
- `aria-live="polite"` 应只在完成时宣告全文，避免每字符播报；状态文本可独立 polite announce。

## Responsive
- **1440**：stage `802.56 × 520px`；editor padding `30 40 104`；before 590px、after 650px。
- **768**：stage `672 × 560px`，位于横排 tabs 下方；外层 wrapper padding 24。
- **390**：stage `306 × 580px`，位于可横滚 tabs 下方；外层 wrapper padding `22px 24px`。
- 390 下双卡必须收敛到 stage 内容宽，不得保留桌面固定 590/650 宽造成横溢；保持 before 压住 after 的负 margin 层叠关系、22px 圆角和标签/正文层级。精确 stage 尺寸优先。

## Reduced motion
- 检测 `matchMedia('(prefers-reduced-motion: reduce)')`。
- reduced=true：切换时立即写入完整 `state.after`、status 直接到完成态、caret 不闪烁；内容与 5 状态不能省略。
- 全局 `transition-duration:.01ms!important; animation-duration:.01ms!important; animation-iteration-count:1!important`。

## Assets
- 5 个实测内联 SVG symbol：`#voice-icon-filler`、`correction`、`paragraphs`、`lists`、`words`；可转为 5 个 React icon，但视觉路径必须来自原 SVG。
- 点阵/柔光是 CSS gradient，无 `<img>` / `<video>`。
- 字体：正文 `MiSans, Geist, Inter, "Noto Sans SC", "PingFang SC", "HarmonyOS Sans SC", "Microsoft YaHei", "OPPO Sans", sans-serif`；meta 用 `"Geist Mono", monospace`。

## AgentDock stage 映射
- 同步使用 `voice-tabs.spec.md` 的 AgentDock 5 项：实时状态、审批提醒、等待输入、用量视图、返回工作区。
- before 白卡表达改造前/当前请求；after 浅紫卡表达 AgentDock 统一结果；status 分别走正在同步/待审批/等待中/汇总中/定位中 → 已统一/已响应/已回复/已汇总/已跳转。
- 审批 after 显示 `Allow / Review / Deny`；用量与文件名只能是演示 mock，禁止真实 PII、密钥、连接串。
