<!-- [skill: go-team-standards · clone-website · 组件取证规格] DesktopNav：桌面导航与动态指示器 -->
# DesktopNav Specification

## Overview
- **唯一目标文件：** `src/components/layout/desktop-nav.tsx`
- **职责：** 桌面导航链接、active/hover/focus 指示器。
- **Interaction model：** hover + focus + scroll-selected active item。
- **Builder 限制：** 只改此目标文件；不实现 HeaderShell 滚动收缩或 MobileMenu。

## Screenshot
- 默认：`./assets/header-1440-default.png`
- hover：`./assets/header-1440-nav-hover.png`

## DOM
```html
<nav class="desktop-nav" aria-label="主要导航">
  <a href="#voice">听写</a><a href="#meeting">记录</a><a href="#agent">Agent</a><a href="#privacy">隐私</a>
  <span class="nav-indicator" aria-hidden="true"></span>
</nav>
```

## Exact computed styles — 1440×900
- `nav`: `display:flex; position:relative; justify-content:center; align-items:center; gap:28px; width:197.664px; height:44px; font-size:13px; color:rgb(218,218,218)`；rect `{x:621,y:18,w:198,h:44}`。
- `a`: `display:flex; align-items:center; height:100%; position:relative; z-index:1; opacity:.68; transition:opacity .18s`。
- `a:hover,a:focus-visible`: `opacity:1`。
- `.nav-indicator`: `position:absolute; left:0; bottom:4px; width:0px; height:1px; opacity:0; background:currentcolor; transition:width .28s cubic-bezier(.22,1,.36,1),transform .28s cubic-bezier(.22,1,.36,1),opacity .18s ease`。
- 已捕获内联 active 样例：`width:26px; transform:translateX(171.664px); opacity:1`。

## States and behaviors
- **default：** 所有 link opacity `.68`；indicator width 0 / opacity 0。
- **hover：** 目标 link opacity 1；indicator width=目标 link 的 `getBoundingClientRect().width`，translateX=目标 link 相对 nav 的 x。
- **focus-visible：** 与 hover 完全相同。
- **scroll-active：** 当前 section 改变时，indicator 移至对应锚点；主题颜色继承 HeaderShell 的 dark/light/blue。
- **language change：** 文本宽度变化后必须重新测量；不得复用固定 26px/171.664px。

## Responsive
- **1440：** 显示，4 项居中。
- **≤900（768/390）：** `.desktop-nav {display:none}`；由 MobileMenu 接管。
- 关键断点：900px。

## reduced-motion
- indicator 与 opacity transition 被全局压到 `.01ms`；active/focus 状态仍准确。

## Resources and text evidence
- 字体继承 HeaderShell 的 MiSans 栈；无图片资产。
- 原文仅取证：「听写 / 记录 / Agent / 隐私」。

## AgentDock mapping
- `#voice→#status`：「听写→状态」。
- `#meeting→#approval`：「记录→审批」。
- `#agent→#integrations`：「Agent→集成」。
- `#privacy` 保持「隐私」。

## Evidence gap
- indicator 数值是动态测量值；仅样例可复现，任何语言/字体载入变化都必须重新计算。
