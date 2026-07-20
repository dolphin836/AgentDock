<!-- [skill: clone-website · component-extraction] MeetingJourney 组件规格（桌面 pin/track/progress 与移动退化全部实测自 https://vokie.com/ #meeting） -->

# MeetingJourney 组件规格

> 数据来源：Chrome DevTools MCP 实测 `https://vokie.com/` 的 `#meeting.meeting-section` 与内部 `#meeting-journey.journey`，含桌面滚动扫描（scrollY → track transform / progress 映射）与 768/390 退化实测。

## Overview

- **目标文件**：`src/components/MeetingJourney.tsx`
- **参考截图（建议补拍）**：`docs/design-references/vokie/meeting-journey-{start,mid,end}-1440.png` + `meeting-journey-stacked-390.png`
- **eyebrow**：`03 / 会议记录`
- **交互模型（INTERACTION MODEL）**：**scroll-driven 横向 pin（GSAP ScrollTrigger 风格）**。桌面下 section 被钉住（`position: fixed`），随纵向滚动把 `.journey-track` 横向平移，扫过 4 张 slide，顶部 1px 进度条同步填充。**≤900px 宽 / ≤699px 高 / reduced-motion 时退化为纵向堆叠，无 pin、无进度条。**

## DOM 结构

```
section#meeting.meeting-section.dark-section.is-journey-pinned   ← 被 GSAP 包进 div.pin-spacer
├─ div.section-inner.meeting-heading            (grid: 标题 800 | lede 480)
│  ├─ div.section-heading
│  │  ├─ p.eyebrow   "03 / 会议记录"
│  │  └─ h2 > strong "想记录时，只需按下快捷键" (+ <br>)
│  └─ p.section-lede "线上会议可同时记录电脑系统声音和麦克风；线下面谈也使用同一套快捷键流程。"
└─ div.journey.is-pinned#meeting-journey
   ├─ div.journey-progress            (1px 轨道)
   │  └─ span                          (蓝色填充，transform: scaleX)
   └─ div.journey-track               (flex row, width 4920px)
      └─ article.journey-slide ×4      (grid: copy 378 | media 688)
         ├─ div.journey-copy          (span.journey-index / h3 / p，flex column space-between)
         └─ div.media-slot.media-slot-dark.media-requirement-slot.has-product-media
            └─ img.product-media
```

## Computed Styles（1440，精确值）

### section#meeting（dark）
- background-color: `rgb(17,17,17)`；height: `900px`（= pin 时的视口高）；padding: `104px 0 24px`
- overflow: hidden；position: relative（未 pin）→ **pin 时 `position: fixed`, top 0**
- 父元素：`div.pin-spacer`（GSAP 生成，撑出滚动距离）

### .meeting-heading
- display: grid；grid-template-columns: `800px 480px`；gap: `80px`；align-items: end；margin: `0 40px 30px`

### 文本
- .eyebrow：`12px/15.6px` `"Geist Mono"` uppercase weight 520，color `rgba(246,248,248,.5)`
- h2 > strong：`30px`，weight **900**，line-height `29.4px`，color `rgb(218,218,218)`
- .section-lede：`19px/32.3px`，color `rgba(246,248,248,.62)`
- .journey-index：`12px` `"Geist Mono"` uppercase weight 520，color `rgba(246,248,248,.42)`
- h3（slide 标题）：`30px`，weight 550，line-height `31.5px`，color `rgb(218,218,218)`
- p（slide 正文）：`17px/28.9px`，color `rgba(246,248,248,.62)`

### .journey-progress / span
- 轨道：height `1px`，width 1360，margin `0 40px 26px`，background `rgba(218,218,218,.2)`，overflow hidden
- 填充 span：height 1px，background `rgb(37,99,235)`（蓝），`transform: scaleX(...)`（初始 `0.05`）

### .journey-track
- display: flex row；gap: `40px`；padding: `0 40px`；margin: `108px 0`
- width: **4920px**（4×1180 + 3×40 gap + 2×40 padding）；`transform: translateX(...)`（初始 0）

### .journey-slide（article）
- display: grid；grid-template-columns: `378.26px 687.74px`；gap: `38px`；padding: `38px`
- width: `1180px`；background-color: `rgb(27,27,27)`；border-radius: `20px`
- .journey-copy：flex column，justify-content space-between（index 顶 / h3+p 底），padding-right 24px

### .media-slot / img.product-media
- media-slot：width 688，height 322.6，position relative，overflow hidden，border-radius `20px`，background `rgb(27,27,27)`
- img.product-media：position absolute，铺满 slot，`object-fit: contain`，`object-position: 50% 50%`，background `rgb(5,6,7)`

## States & Behaviors —— 桌面 pin / track / progress（实测滚动映射）

- **pin 机制**：`#meeting` 外层被包进 `div.pin-spacer`（offsetTop 3915，撑高 ≈ 4380px）。当 section 顶部到达视口顶 (`secTop = 0`) 时 `position` 由 `relative` 变 **`fixed`**（钉住）；journey 在视口内固定于 `top ≈ 234px`（标题在其上）。滚到 spacer 末端后恢复 `relative`。
- **pin 滚动区间**：`scrollY 3915（pin 开始）` → `≈ 7395（pin 结束）`，pin 滚动距离 ≈ **3480px**（正好 = track 溢出量 4920−1440）。1:1 线性 scrub。
- **track 横移**：`.journey-track` `translateX` 从 `0` 线性到 **`-3480px`**（scrub 绑定 pin 进度 `p = (scrollY − 3915)/3480`，clamp[0,1]）。实测采样：

  | scrollY(约) | secPos | track translateX | progress scaleX |
  |---|---|---|---|
  | 3915 | relative→fixed 临界 | 0 | 0.05 |
  | 3921 | fixed | ~ -1 | 0.05 |
  | 4284 | fixed | -126 | 0.106 |
  | 4983 | fixed | -774 | 0.307 |
  | 6048 | fixed | -1931 | 0.613 |
  | ≥7395 | relative | **-3480（封顶）** | **1（封顶）** |

- **progress 填充**：`span` `scaleX` 从 `0.05` → `1`，随 pin 进度插值（`transform-origin: left`），颜色 `rgb(37,99,235)`。
- **transition**：位移/缩放为 scrub（跟随滚动，无固定 duration）；页面使用平滑滚动库（滚动位移与像素非严格 1:1，采样受缓动影响，终态精确）。

## Per-Slide Content（逐字实测，4 张全）

| # | index | h3 | p | 媒体图 |
|---|---|---|---|---|
| 1 | 01 | 按下快捷键 | 不用邀请机器人入会，也不必切换会议软件。 | `product-media/meeting-shortcut.png` (1320×1038) |
| 2 | 02 | 照常开会 | 腾讯会议、飞书、Zoom 或线下面谈，都不改变原来的会议路径。 | `assets/meeting-sources-*.png` (1320×1038) |
| 3 | 03 | 会后打开最近录音 | 查看完整转写与内容摘要，不必翻找会议软件历史。 | `assets/meeting-recording-*.png` |
| 4 | 04 | 找到行动项 | 接下来由你复制、分配，或连接自己的工作流。 | `assets/meeting-action-items-*.png` |

## Assets
- 4 张 `img.product-media`（PNG，源图 1320×1038，`object-fit: contain`）。需下载到 `public/product-media/`。
- 深色底 `rgb(17,17,17)` / slide `rgb(27,27,27)` / 媒体底 `rgb(5,6,7)`。字体同 VoiceSection。

## Responsive Behavior

| 断点 | 布局 | pin | track | progress | slide |
|---|---|---|---|---|---|
| **1440** | heading grid `800/480` | **有**（fixed 钉住） | flex **row** 4920px，scrub 横移 | 显示，scaleX scrub | grid `378/688`，1180 宽 |
| **768** | heading **单列** 720 | **无**（relative） | flex **column**，堆叠高 ~2644 | `display:none` | grid `202/404`（仍左右两栏），720 宽 |
| **390** | 单列 | **无** | flex column，堆叠高 ~2526 | none | grid **单列** 310（copy 上 / media 下），media-slot 高 ~319，padding 22 |

- **退化断点**：`@media (max-width:900px), (max-height:699px), (prefers-reduced-motion:reduce)` → `.journey{overflow:visible}`、`.journey-track{flex-direction:column;margin-inline:auto;padding-bottom:44px}`、`.journey-slide{flex:0 0 auto;width:100%}`、`.journey-progress{display:none}`。即 **≤900px 即进入纵向堆叠**（768 已是退化态）。

## Reduced-motion（实测）
- 命中上面同一退化断点：**取消 pin 与横向 scrub**，4 张 slide 纵向堆叠，进度条隐藏，正常纵向阅读。
- 全局 `transition/animation ≈ .01ms`，`scroll-behavior:auto`；`[data-reveal]` 直接终态。

## AgentDock 替换映射（状态 / 审批 / 用量 / 返回）

保留"标题 + 顶部进度条 + 4 张横向 pin slide + 每张 copy/media 两栏 + 退化纵向堆叠"结构，把"会议记录四步"替换为 **AgentDock 使用旅程四步**（对应设计稿 IA 的实时状态 / 审批 / 用量 / 返回）：

| # | AgentDock index/h3 | p（说明） | media（产品界面 mock） |
|---|---|---|---|
| 01 | 安装并授予本地权限 | 通过本地 hooks 接入，无需云端账号，通知在本机产生。 | 安装/权限界面截图 |
| 02 | **看见实时状态** | 刘海统一显示 Claude Code、Codex、Cursor 的运行/等待/空闲。 | 刘海状态总览 |
| 03 | **审批与用量** | 收到 Allow / Review / Deny 提醒，并在同一入口查看各 Agent 用量。 | 审批三态 + 用量视图 |
| 04 | **返回工作区** | 点击会话直接跳回对应终端或编辑器，减少注意力切换。 | 会话回跳演示 |

- eyebrow → `02 / 使用旅程`（或按 AgentDock 章节号）；进度条颜色沿用 AgentDock 主色（当前蓝 `rgb(37,99,235)` 可保留）。
- **必须保留退化逻辑**：≤900px / reduced-motion 关闭 pin，改纵向堆叠（对应设计稿"移动端无水平溢出、支持 reduced-motion"成功标准）。
- media 为真实 AgentDock 界面截图（展示产品，不用抽象插画——设计原则 1）；不得含真实 PII/密钥（铁律 12）。
