<!-- [skill: go-team-standards · 技术文档] Vokie 首页浏览器取证：页面拓扑与响应式层级 -->
# PAGE TOPOLOGY — Vokie 首页现场取证

## 证据范围

- 目标：`https://vokie.com/`；取证日期：2026-07-20。
- 观察手段：Chrome DevTools 真实页面、可访问性树、计算样式、布局几何、1440/768/390 视口切换、滚动状态与交互状态。
- 对照素材（均已读取）：
  - `/Users/eric/AgentDock-vokie-homepage/website/docs/design-references/vokie/vokie-desktop-1440.png`
  - `/Users/eric/AgentDock-vokie-homepage/website/docs/design-references/vokie/vokie-mobile-390.png`
  - `/Users/eric/AgentDock-vokie-homepage/website/docs/design-references/vokie/vokie-mobile-menu-390.png`
- 文件校验事实：
  - desktop：`1440 × 16018`，SHA-256 `b15a4e19cd68d34aa60b1c5626b78921ef37840c0ddaca24c668dccc9aa8392e`。
  - mobile：`780 × 31222`，SHA-256 `5639dc76f4172f98b441b1de49c53ae2c7679ca63de45edfca5f3b490bec45e6`；由 390 CSS px、DPR 2 的 full-page capture 生成。
  - mobile menu：`780 × 1688`，SHA-256 `90ae0bc1ecd25f02b0696316e3e882f3207f2b11218238c19e156d93eb62458e`；由 390×844 CSS px、DPR 2 的当前 viewport capture 生成。
- 可复现方式：在 `website/` 执行 `npm run capture:reference`；具体浏览器流程定义于 `/Users/eric/AgentDock-vokie-homepage/website/scripts/capture-vokie-reference.mjs`。脚本等待页面网络空闲和 2.6 s 稳定时间，分别采集 1440 桌面 full page、390 移动 full page，并在移动端点击 `#menu-toggle`、等待 500 ms 后采集菜单 viewport。
- 本文记录的是可复现的浏览器事实，不是实现规范；不包含任何品牌文案复用建议。

## 0. PNG 可直接支持的构图证据

| 参考图 | 截图中直接可见的事实 | 可支持结论 |
|---|---|---|
| `vokie-desktop-1440.png` | 一条连续的超长单页；首屏是深色大画布与居中大标题；后续由全宽深/浅色区块串联；若干产品示意框横向并排，四周保留大面积负空间。 | 1440 采用章节式纵向叙事、“大标题核心 + 稀疏辅助信息”的 hero 层级，以及适合横向轨道/并排内容的宽屏构图。 |
| `vokie-mobile-390.png` | 同一章节顺序被压缩为窄幅单列；header 更紧凑；桌面横向内容在移动长图中转为纵向堆叠；深/浅色 section 仍保持全宽分界。 | 390 保留桌面信息层级和色彩节奏，但重排为单列、显著增加页面纵向长度，不保留桌面横向展开形态。 |
| `vokie-mobile-menu-390.png` | 844 CSS px 高的深色满屏菜单；header 留在顶部；主导航为 2×2 大触控格；下载入口位于独立的跨栏底行；细分隔线明确划分触控区域。 | 菜单打开态是覆盖内容的移动专用信息架构，而不是桌面导航简单换行；主导航与下载入口有明确的层级分离。 |

### 响应式证据边界

- desktop 与 mobile full-page 图可直接对比宽屏横向并排和 390 单列堆叠；mobile 物理宽 780 px 是脚本中 390 CSS px × DPR 2 的结果。
- menu 图可直接佐证 390 打开态的满屏深色构图、2×2 主导航与跨栏下载行；ARIA、z-index 和动画参数仍采用 Chrome 运行时证据。
- 静态 PNG 不能单独证明 fixed/sticky/pin、动画时长、easing 或精确触发阈值；这些结论仍由 DevTools 扫描支持。

## 1. 运行时根层级

| 层级（由前到后） | 定位 / z-index | 观察到的职责 |
|---|---:|---|
| Skip link | `fixed`, `z-index: 200`；初始在可视区上方 | 键盘跳至 `main` 的辅助入口。 |
| Site header | `fixed`, `top: 0`, `z-index: 100` | 始终悬于文档内容上方；桌面为 80 px 高，≤900 px 为 64 px。 |
| Mobile menu | `fixed`, `inset: 0`, `z-index: 90` | 仅 ≤900 px `display: grid`；在 header 下方层级显示满屏遮罩。 |
| Main | 普通文档流 | 十个主 section（桌面宽屏时会议段被 `.pin-spacer` 包裹）。 |
| Footer | 普通文档流 | 独立页脚导航与联系信息。 |

**层级结论：** header 高于 menu（100 > 90），两者均高于常规内容；menu 打开时并未覆盖 header。

## 2. Section 顺序与 1440 宽屏几何

以下坐标来自 **1440 × 1000 CSS px**、页面初始加载后的 live DOM；页面总高 16,018 px。`top` 是文档坐标而非当前可视坐标。

| 顺序 | DOM 锚点 / 语义 | top | 高度 | 容器与滚动模型 |
|---:|---|---:|---:|---|
| 1 | `#top` | 0 | 976 | 深色首屏；`position: relative`、`overflow: hidden`；内部有 `#hero-canvas`。 |
| 2 | `#product` | 976 | 1,003 | 浅色价值卡片段；`position: relative`、`overflow: clip`，带 reveal band。 |
| 3 | `#context-focus` | 1,979 | 1,000 | 浅色粒子/上下文过渡段；`position: relative`、`overflow: hidden`。 |
| 4 | `#voice` | 2,979 | 1,136 | 浅色能力示例段；普通文档流。 |
| 5 | `.pin-spacer` → `#meeting` | 4,115 | 4,480 | 宽屏唯一 pin 区：spacer 使会议 journey 留在可视区并将横向轨道映射到纵向滚动。 |
| 6 | `#outcomes` | 8,595 | 1,149 | 浅色结果/手风琴段。 |
| 7 | `#context` | 9,744 | 3,636 | 深色上下文世界段；`position: relative`、`overflow: clip`；包含个性化、Agent、愿景子章。 |
| 8 | `#memory` | 13,380 | 805 | 深色产品截图段。 |
| 9 | `#privacy` | 14,186 | 638 | 深色数据边界段。 |
| 10 | `.final-cta` | 14,823 | 716 | 深色收束 CTA。 |
| — | `#footer` | 15,539 | 479 | 页脚。 |

### 2.1 结构内的主要交互容器

- `#product`：四张 card；桌面可访问性树将标题暴露为可展开 button。
- `#voice`：五项 horizontal tablist + 一个 tabpanel；仅一个 tab 处于 `aria-selected="true"`。
- `#meeting`：四个顺序步骤。在桌面宽屏中，该段位于 pin/spacer 机制内。
- `#outcomes`：三项 accordion；加载态第 1 项为 `aria-expanded="true"`，其余为收起状态。
- `#context`：两个章节式子段及一个结尾陈述；非独立页面级 section。

## 3. 固定、sticky、pin 与滚动边界

### 固定 / pin 事实

1. Header 与 skip link 是唯一观察到的固定定位元素。
2. 宽屏（1440）存在单个 `.pin-spacer`，高度 4,480 px；它包围会议 journey。该段不是 sticky DOM，而是运行时 pin 产生的 spacer。
3. `#context-focus`、hero 和 context 段均为相对定位并裁切内部视觉层；没有测得其他 sticky section。
4. 首屏 canvas 与上下文 canvas 是 section 内部视觉层，不构成独立的页面固定层。

### Header 状态阈值（1440 × 900 验证）

| 滚动位置 | 前状态 | 后状态 / 实测边界 |
|---:|---|---|
| 0–198 px | `.site-header` | 宽约 1360 px、高 80 px、顶部 0。 |
| 199 px（首次检出点） | 普通 header | 变为 `.site-header.is-scrolled`。 |
| 200–360 px | condensed header | 容器连续收缩，约从 1194×72 px 收敛到 920×58 px，顶部约 11 px。 |

这是浏览器扫描得到的 **198–199 px 离散边界**，而非从源码推测的常量；没有在本次观测中测得一个更低层的动画完成事件。

## 4. 响应式扫描

### 4.1 1440 × 1000

- 桌面导航可见；header 为 80 px。
- `#meeting` 处于 `pin-spacer` 内，页面高度为 16,018 px。
- 主要 section 是宽屏横向排布/固定旅程的组合。

### 4.2 768 × 1024

| 观察项 | 事实 |
|---|---|
| Header | 64 px；desktop nav `display: none`；44×44 px menu toggle 出现。 |
| Mobile menu | 已切换为 grid 叠层，但初始 `opacity: 0`、`pointer-events: none`。 |
| Hero | 1000 px 高。 |
| `#product` | 1,119 px 高。 |
| `#context-focus` | 1,024 px 高（整屏高）。 |
| `#voice` | 1,400 px 高。 |
| Meeting | 直接是 `#meeting`，高 3,218 px；没有 1440 宽屏的 `.pin-spacer`。 |
| 页面后段 | `#outcomes` top 7,762；`#context` top 9,087；最终 CTA 高 1,035 px。 |

### 4.3 390 × 844（DPR 2、mobile + touch）

| 观察项 | 事实 |
|---|---|
| Header / nav | 64 px fixed header；desktop nav 隐藏；44×44 px menu toggle。 |
| Hero | 高 826 px（接近 `100svh - 18px`）；内容宽 354 px；标题计算字号 39 px。 |
| `#product` | 高 2,420 px，card 内容转为纵向长段。 |
| `#context-focus` | 高 844 px（恰为 viewport 高）。 |
| `#voice` | 高 1,166 px。 |
| Meeting | 高 2,972 px，普通纵向步骤，不 pin。 |
| 后段 | `#outcomes` 985 px；`#context` 3,443 px；`#memory` 606 px；`#privacy` 813 px；CTA 825 px；footer 712 px。 |
| 产品 card 的 a11y 形态 | 标题由桌面可展开 button 变成 heading，未暴露为 button。 |

## 5. 未作为事实写入的项目

- 未从静态截图推断 fixed/sticky/pin、动画时长、easing 或交互触发阈值；这些参数只采用浏览器运行时证据。
- 未把未观测到的 hover、焦点、卡片开合时长、滚动惯性或第三方字体加载细节补写为“精确值”。
- 本文不把产品文字、名称或视觉资产转化成实现文案建议。
