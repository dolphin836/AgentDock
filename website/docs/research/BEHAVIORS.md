<!-- [skill: go-team-standards · 技术文档] Vokie 首页浏览器取证：交互、时序与无障碍运动 -->
# BEHAVIORS — Vokie 首页现场取证

## 证据纪律

- 目标：`https://vokie.com/`；取证日期：2026-07-20。
- 仅记录 Chrome DevTools 对真实页面所见的 DOM、ARIA、计算样式、点击后状态和视口状态。
- 已复核以下本地图像：
  - `/Users/eric/AgentDock-vokie-homepage/website/docs/design-references/vokie/vokie-desktop-1440.png`
  - `/Users/eric/AgentDock-vokie-homepage/website/docs/design-references/vokie/vokie-mobile-390.png`
  - `/Users/eric/AgentDock-vokie-homepage/website/docs/design-references/vokie/vokie-mobile-menu-390.png`
- 三张图已分别校验：desktop `1440 × 16018`（SHA-256 `b15a4e19…`）、mobile `780 × 31222`（`5639dc76…`）、mobile menu `780 × 1688`（`90ae0bc1…`）。
- 可复现方式：在 `website/` 执行 `npm run capture:reference`。脚本 `/Users/eric/AgentDock-vokie-homepage/website/scripts/capture-vokie-reference.mjs` 明确设置 desktop 1440×1000/DPR 1、mobile 390×844/DPR 2；菜单图是在点击 `#menu-toggle` 并等待 500 ms 后采集的当前 viewport。
- 术语“未测得”表示没有把猜测写成参数。本文没有任何品牌文案的实现建议。

## 1. Interaction model

| 区域 | 触发器 | 前状态 | 后状态 / 语义 | 导航或副作用 |
|---|---|---|---|---|
| 跳至主内容 | 键盘/链接激活 | fixed、视觉上移出 viewport | 焦点跳至 `main` | 同页锚点。 |
| Header | 页面 scroll | 正常 header | 在 198–199 px 之间进入 `.is-scrolled`；容器收缩为居中胶囊式规格 | 不改变文档顺序。 |
| 主导航 | 点击锚点链接 | 当前滚动位置 | 跳转到相应 section 锚点 | 同页定位；桌面可见，≤900 px 隐藏。 |
| 语言切换 | button | 当前语言 | 未在本次记录中切换，以免把语言版本混为主页行为取证 | 不主张结果。 |
| Hero 次级 CTA | button | 无 dialog、无新页面 | 真实点击后仍留在同页；button 保持焦点；未测得可见 dialog 或 URL 变化 | 存在 `role=status` / `aria-live="polite"` 容器，但点击后读值为空，因此不将提示文本、延时或状态写为事实。 |
| 价值 card | 桌面 button | `aria-expanded` 可用 | 可展开控件语义存在 | 390 端改为 heading，未暴露成 button。 |
| Voice 示例 | tab | 一项 `aria-selected="true"` | 点击另一项后选中态移到该 tab，tabpanel 内容立即更新 | 单选 tablist；无新页面。 |
| 结果段 | accordion button | 第 1 项初始展开，其余收起 | button / region 的 `aria-expanded`、`region` 关系表达展开内容 | 单选或多选策略未在本轮逐项切换验证，故不推断。 |
| 下载入口 | link | 当前页 | 目标是 `/download.html` | 同页外部导航。 |
| 邮件 / 社群 | link | 当前页 | `mailto:` 或外部邀请链接 | 浏览器默认链接行为。 |

## 2. 精确可测的 motion 参数

### 2.1 390 mobile menu

**关闭态（实测）：**

- `#mobile-menu`: `opacity: 0`、`pointer-events: none`、`position: fixed`、`inset: 0`。
- 每个菜单 link：`clip-path: inset(100% 0 0)`。
- menu link 计算 transition：`clip-path 0.42s cubic-bezier(0.62, 0.16, 0.13, 1.01)`。

**打开触发（真实点击 menu toggle）：**

| 字段 | 打开后实测值 |
|---|---|
| Toggle | `aria-expanded="true"`。 |
| Overlay | `aria-hidden="false"`、`inert=false`、`opacity: 1`、`pointer-events: auto`。 |
| Body | 追加 `menu-open` class。 |
| 所有 link | `clip-path: inset(0)`。 |

**层级与布局：**

- Overlay 在 header 下层（`z-index: 90` vs `100`），覆盖 390×844 viewport。
- mobile nav 是两列 grid；最后一项跨两列。
- CSS 关闭/打开 opacity transition 为 `0.32s`。link reveal duration 为 `0.42s`，easing 如上。
- 已观测到链接“关闭时裁切、打开时完全可见”；浏览器采样在点击完成后才取得首个状态，因此不把逐项 delay 记为实测。
- `vokie-mobile-menu-390.png` 直接显示打开后的 390×844 viewport：深色遮罩覆盖正文、header 保持可见、四个主导航项组成 2×2 大格，下载入口单独跨越整行。截图支持最终构图；ARIA、层级和 0.32/0.42 s 参数由 390×844 Chrome 实际点击与计算样式支持。

### 2.2 Voice tab 切换

点击第二个 tab 后：

1. 原 tab 的 `aria-selected` 由 `true` 变为 `false`。
2. 点击目标成为唯一 `aria-selected="true"` 的 tab。
3. tabpanel 内容替换为相应的示例卡。
4. 0 / 300 / 650 / 1250 ms 读取时目标内容都已存在。

因此：**内容替换发生在 0 ms 采样点之前或同一任务内**；没有把这误报为持续 1.25 s 的 panel transition。

### 2.3 持续 CSS 动画（1440 live page）

实时动画树中可见：

| 元素 | duration | easing | iterations | 观察 |
|---|---:|---|---:|---|
| `.voice-editor-caret` | 980 ms | `linear` | 无限 | 语音编辑器光标。 |
| 6 个波形 `<i>` | 840 ms | `linear` | 无限 | 同一波形组以不同负延时交错。 |

这两类是 Web Animations API 当前返回的实际 timing，不是视觉估计。

## 3. Scroll-linked model

### 3.1 Header

- **触发边界：** 1440×900 的离散滚动扫描中，198 px 仍未带 `.is-scrolled`，199 px 首次带该 class。
- **前状态：** inner container 约 1360×80 px、top 0。
- **后状态：** 199 px 后开始收缩；200 px 时约 1194×72 px，到 360 px 约 920×58 px、top 约 11 px。
- **时长/easing：** 本轮没有提取到一个可可靠归因于 header 的 CSS transition duration；因此只记录连续几何变化，不声明一个虚构时长。

### 3.2 `#product` reveal band

- 容器有 `overflow: clip`。
- 1440 初始 live style 已可见 `clip-path: inset(0 91.0267% 0 0)`，随滚动到 320 px 变化为约 `inset(0 34.122% 0 0)`。
- 这是 scroll-linked 的连续 clip reveal，而不是一次性离散淡入。
- 本轮没有把完整触发区间测完，因此不把“开始/结束百分比”作为现场事实。

### 3.3 宽屏会议 journey

- 仅 1440 宽屏观测到 `.pin-spacer`（4,480 px 高）。
- 该 spacer 将会议 journey 固定，并以额外的纵向滚动距离呈现横向内容。
- 768 与 390 都没有该 spacer：meeting 回落为普通垂直段。
- 固定开始/结束的精确 px 在本次多端扫描中没有完整定标，故不填未经验证的数值。

## 4. Hover、focus 与可访问性

| 模式 | 证据 | 结论 |
|---|---|---|
| Desktop input | 1440 live media：`hover: hover`、`pointer: fine`。 | 桌面可使用 hover；但本轮没有观测到某个特定 hover 的视觉前后差，故不虚构 hover 规格。 |
| Touch input | 390：`mobile + touch`；menu toggle 与 tab 均可点击。 | 核心流程不依赖 hover。 |
| Menu 语义 | toggle 的 `aria-expanded` / label 在开闭间变更；overlay 同步更新 `aria-hidden` 与 `inert`。 | 可访问性状态与视觉开闭联动。 |
| Tab 语义 | `tablist`、`tab`、`tabpanel`、`aria-selected`。 | 单活跃 tab 的模式可由辅助技术读取。 |
| Accordion 语义 | button `aria-expanded` 与对应 region。 | 展开内容有可读区域关系。 |
| Skip link | fixed `z-index: 200`。 | 高于 header/menu，键盘路径优先。 |

## 5. Reduced motion

浏览器加载的样式表中存在下列可验证媒体规则：

```css
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, ::before, ::after {
    scroll-behavior: auto !important;
    transition-duration: 0.01ms !important;
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
  .intro-curtain { display: none; }
  .motion-ready [data-reveal] { opacity: 1; transform: none; }
}
```

同一媒体条件还让 `.journey` 采用普通溢出、`.journey-track` 改为纵向 column，并隐藏 `.journey-progress`。这表示 reduced motion 与窄屏/低高度同样取消横向 pin journey，而不是只减少时长。

## 6. 断点与行为差异摘要

| 行为 | 1440 | 768 | 390 |
|---|---|---|---|
| Header | 80 px + desktop nav；199 px 后进入 condensed 状态。 | 64 px + hamburger。 | 64 px + hamburger。 |
| Navigation | 内联 desktop links。 | 满屏 menu overlay 可用。 | 满屏 2 列 menu overlay；关闭/打开的 clip-path 参数已测得。 |
| Meeting | pin/spacer、滚动驱动 journey。 | 普通纵向 meeting。 | 普通纵向 meeting。 |
| Product cards | 可展开 button 暴露。 | 未逐项语义复测。 | heading 暴露，不是 button。 |
| Hero | 宽屏 canvas 首屏。 | 1000 px 高。 | 826 px 高，使用接近动态 viewport 的高度模型。 |

### 6.1 PNG 对行为与响应式结论的支持程度

| 证据项 | PNG 直接支持 | 仍需浏览器证据 |
|---|---|---|
| 章节节奏 | 超长单页由全宽深/浅色区块交替组成；首屏大标题与大面积留白形成明确开场层级。 | section 的 DOM 顺序、精确 top/height。 |
| 桌面构图 | 产品示意框可横向并排；主体内容处于宽阔画布内，不是单列窄屏构图。 | 横向 journey 是否 pin、pin 的滚动长度。 |
| 390 重排 | `vokie-mobile-390.png` 显示紧凑 header、单列章节和纵向堆叠卡片；相同内容顺序在窄屏中形成显著更长的页面。 | 64 px 精确 header 高度、section 精确高度和移动 card 的 a11y 语义。 |
| 390 菜单 | `vokie-mobile-menu-390.png` 显示满屏深色打开态、header、2×2 主导航格与跨栏下载行。 | z-index、ARIA 前后态、0.32/0.42 s 时序。 |
| 动画 | 静态 PNG 只能显示某一瞬间。 | duration、easing、scroll threshold、reduced-motion。 |

## 7. 未测得 / 不应补写

- 未测得 hero CTA 的可见提示内容和寿命。
- 未测得 card、accordion 的全部前后动画 timing。
- 未测得每个 hover 的前后样式，故没有把 CSS 可能存在的 `:hover` 规则当成体验事实。
- 三张参考 PNG 已分别核对；构图和最终状态由对应截图支持，交互机制与时序只采用浏览器运行时证据。
