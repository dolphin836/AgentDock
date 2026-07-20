<!-- [skill: clone-website · component-extraction] OutcomesAccordion 组件规格（全部状态实测自 https://vokie.com/ #outcomes） -->

# OutcomesAccordion 组件规格

> 数据来源：Chrome DevTools MCP 实测 `https://vokie.com/` 的 `#outcomes.outcomes` 与 `#outcome-accordion`，含展开/收起互斥切换、chevron ±图标伪元素、1440/768/390 布局实测。

## Overview

- **目标文件**：`src/components/OutcomesAccordion.tsx`
- **参考截图（建议补拍）**：`docs/design-references/vokie/outcomes-{item1,item2,item3}-1440.png`
- **eyebrow**：`04 / 一次录音，三个结果`
- **交互模型（INTERACTION MODEL）**：**click-driven 互斥手风琴（single-open accordion）**。3 个 `<button.outcome-trigger>`，点击展开对应 `.outcome-detail`（内含产品截图），同时收起其余；默认第 1 项展开。`aria-expanded` 同步 true/false。

## DOM 结构

```
section#outcomes.outcomes.light-section
└─ div.section-inner
   ├─ div.outcomes-heading[.is-visible]
   │  ├─ p.eyebrow  "04 / 一次录音，三个结果"
   │  ├─ h2         "会后，不必从头翻录音"
   │  └─ p          "本地音视频文件也可以进入同一套转写与整理流程。"
   └─ div.outcome-accordion#outcome-accordion
      └─ article.outcome-item[.is-active] ×3
         ├─ button.outcome-trigger#outcome-trigger-{transcript|summary|actions}  [aria-expanded]
         │  ├─ span.outcome-index          "01"/"02"/"03"
         │  ├─ span.outcome-copy           (标题 span + small.outcome-subtitle)
         │  └─ i[aria-hidden]              (± 图标，::before/::after 两根横条)
         └─ div.outcome-detail#outcome-detail-{...}
            └─ div.media-slot.media-requirement-slot.has-product-media
               └─ img.product-media
```

## Computed Styles（1440，精确值）

### section#outcomes（light）
- background 浅色（light-section）；color `rgb(9,9,9)`
- .section-inner：margin `0 40px`（1360 宽）
- .outcome-accordion：margin `0 80px`（**1200 宽**，比 section-inner 再内缩 40）

### .outcomes-heading
- .eyebrow：`12px` `"Geist Mono"`，color `rgb(9,9,9)`
- h2：`30px`，weight 560，line-height `30px`，color `rgb(9,9,9)`
- 下方说明 p：正文色 `rgb(83,83,83)`

### .outcome-item（article）
- border-bottom：`1px solid rgba(17,17,17,.2)`（分隔线）；padding 0；无背景色
- 激活/非激活边框、padding 相同（差异只在 detail 展开与 ± 图标）

### .outcome-trigger（1440 桌面）
- display: grid；**grid-template-columns: `48px 341.41px 656.59px 34px`**；column-gap `40px`；align-items start；padding `31px 0`；cursor pointer；color `rgb(9,9,9)`
- 说明：桌面下第 3 列（656px）为**媒体预留列**——展开时媒体横向出现在标题右侧同一行区域内。
- .outcome-index：`12px` `"Geist Mono"`，color `rgb(83,83,83)`，宽 48
- .outcome-copy 标题（首 span）：`30px`，weight 550，line-height `31.5px`，color `rgb(9,9,9)`
- .outcome-subtitle：`17px`，color `rgb(83,83,83)`，margin-top `10px`

### chevron `<i>`（34×34，± 图标，纯伪元素）
- `i`：34×34，无边框/背景；`::before` 与 `::after` 各为 `18px × 1px` 实心条 `rgb(9,9,9)`，居中（translateX −9）。
- **收起态（+）**：`::before` 水平；`::after` 旋转 90°（`matrix(0,1,-1,0,…)` 竖直）→ 组成 **加号 +**。
- **展开态（−）**：`::after` 回到水平（`matrix(1,0,0,1,…)`）与 `::before` 重合 → 组成 **减号 −**。
- 切换即 `::after` 的 90°↔0° 旋转（配合全局过渡）。

### .outcome-detail（媒体容器）
- **展开(is-active)**：`display: block`；overflow hidden；height ≈ `440.66px`；margin `31px 0 36px`；宽 657
- **收起**：`display: none`；height 0
- .media-slot：`aspect-ratio: 960/661`；border-radius `8px`；background `rgb(231,231,231)`；overflow hidden
- img.product-media：`object-fit: contain`；`object-position: 50% 50%`；640×441（桌面）
- 说明：`.outcome-detail` 与 `.outcome-item` 的 `transition` 计算值为 `all 0s`（无 CSS 过渡）→ 展开/收起为 **display 切换 + JS 高度动画**（reduced-motion 下瞬时）。

## States & Behaviors

### 行为：手风琴展开/收起（互斥）
- **触发**：点击 `.outcome-trigger`（原生 button，键盘可达）。
- **状态**：被点 item 加 `.is-active` 且 `aria-expanded="true"`，其 `.outcome-detail` `display:block`（高度 0→~440 展开、显示媒体）；**其余全部收起**（`is-active` 移除、`aria-expanded="false"`、detail `display:none` 高度 0）。
- **实测互斥验证**：点击第 2 项后 `is-active = [false,true,false]`，detail 高度 `[0,209/440,0]`，aria `[false,true,false]`。
- **图标联动**：激活项 ± 变 −，其余为 +。
- **默认态**：第 1 项（transcript）展开。

## Per-Item Content（逐字实测，3 项全）

| # | index | 标题 | 副标题(outcome-subtitle) | 媒体图 |
|---|---|---|---|---|
| 1 | 01 | 完整转写 | 按时间回看说过什么。 | `product-media/transcript.webp` |
| 2 | 02 | 内容摘要 | 快速抓住讨论重点。 | `product-media/summary.webp` |
| 3 | 03 | 行动项 | 看清接下来要做什么。 | `product-media/actions.webp` |

- 标题文案色：激活/非激活均 `rgb(9,9,9)`（无变暗）。

## Assets
- 3 张 `img.product-media`（webp，`object-fit: contain`，媒体框 `aspect-ratio 960/661`）。下载到 `public/product-media/`。
- 媒体框底色 `rgb(231,231,231)`，圆角 8px。字体同前。

## Responsive Behavior

| 断点 | trigger grid | 媒体位置 | detail 展开高 | section-inner margin |
|---|---|---|---|---|
| **1440** | `48px 341px 657px 34px`，gap 40，padding `31px 0` | **横向**：媒体在标题右侧同行（第 3 列 657） | ~440（640×441 图） | `0 40`；accordion `0 80` |
| **768** | `44px 602px 34px`，gap 20 | **下方堆叠**：媒体在标题下方 | ~441（656 宽） | `0 24` |
| **390** | `36px 260px 30px`，gap 14，padding `24px 0` | 下方堆叠 | ~209（304 宽），标题 29px | `0 18` |

- 关键切换：**桌面(1440)** 触发器为 4 列、媒体与标题**同行横向**展开；**≤768** 收敛为 3 列、媒体**改到标题下方纵向**展开。

## Reduced-motion（实测）
- 全局 `transition/animation ≈ .01ms!important`、`scroll-behavior:auto`、`[data-reveal]` 直接终态。
- 手风琴展开/收起本就无 CSS 过渡（`all 0s`）→ reduced-motion 下高度 JS 动画应直接落终态（瞬时展开/收起）。仍保留 `aria-expanded` 与 display 切换，键盘/读屏可用。

## AgentDock 替换映射（状态 / 审批 / 用量 / 返回）

保留"章节标题 + 3 项互斥手风琴 + ± 图标 + 右侧/下方产品截图"的结构，把"一次录音三个结果"替换为 **AgentDock「一个刘海，多种掌控」** 的三/四类能力（对应设计稿 IA 的实时状态 / 审批 / 用量 / 返回）。建议 3 项（也可扩到 4 项，结构同样成立）：

| # | AgentDock 标题 | 副标题 | 展开媒体（真实界面 mock） |
|---|---|---|---|
| 01 | **实时状态** | 一眼看清 Claude Code / Codex / Cursor 在运行、等待还是空闲。 | 刘海统一状态截图 |
| 02 | **审批提醒** | Allow / Review / Deny 就地响应，含等待中状态。 | 审批三态截图 |
| 03 | **用量视图** | 各 Agent 用量/额度在同一入口呈现。 | 用量视图截图 |
| （04）| **返回工作区** | 点击会话跳回对应终端或编辑器。 | 会话回跳截图 |

- eyebrow → 如 `05 / 一个刘海，多种掌控`；index 01/02/03 保留等宽字体质感。
- ± 图标、互斥展开、默认展开第 1 项、`aria-expanded`、键盘可达 **全部保留**（满足设计稿键盘导航成功标准）。
- 展开媒体用真实 AgentDock 界面截图；审批/用量为演示 mock，不得含真实用户 PII / 密钥 / 连接串（铁律 1、12）。
