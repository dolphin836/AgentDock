<!-- [skill: go-team-standards · clone-website · 组件取证规格] HeaderShell：品牌、actions、主题与滚动收缩行为 -->
# HeaderShell Specification

## Overview
- **唯一目标文件：** `src/components/layout/header-shell.tsx`
- **职责：** 固定外壳、品牌、语言/下载/menu actions、skip-link 样式契约、主题与滚动状态。
- **Interaction model：** scroll-driven + click + focus。
- **Builder 限制：** 只改此目标文件；DesktopNav 与 MobileMenu 只通过 props/children 引入。

## Reference screenshots
- 默认：`./assets/header-1440-default.png`
- 收缩：`./assets/header-1440-scrolled.png`
- 平板/移动：`./assets/header-768-default.png`、`./assets/header-390-default.png`

## DOM
```html
<a class="skip-link" href="#main-content">跳到主要内容</a>
<header class="site-header" id="site-header" data-header-theme="dark">
  <div class="site-header-inner">
    <a class="brand-link" href="#top"><img class="brand-symbol" width="24" height="24"><span class="brand-name">Vokie</span></a>
    <!-- DesktopNav child -->
    <div class="header-actions">
      <button class="language-toggle"><span id="current-lang">EN</span></button>
      <a class="bracket-link bracket-link-small" href="/download.html"><span>下载 Vokie</span></a>
      <button class="menu-toggle" aria-expanded="false" aria-controls="mobile-menu"><span></span><span></span><span></span><span></span></button>
    </div>
  </div>
</header>
```

## Tokens and resources
```css
--carbon:#111; --paper:#dadada; --paper-pure:#e7e7e7; --ink:#090909; --graphite:#535353;
--vokie-blue:#2563eb; --vokie-blue-dark:#1d4ed8; --header-height:80px; --page-gutter:40px; --content-width:1440px;
--ease-out:cubic-bezier(.22,1,.36,1); --ease-structural:cubic-bezier(.62,.16,.13,1.01);
```
- 字体：MiSans Regular/Semibold；Geist Mono variable。图标：`/vokie-symbol.svg` 24×24。

## Exact computed styles — 1440×900 dark default
- `header`: `position:fixed; inset:0 0 auto; z-index:100; width:1440px; height:80px; background-color:rgba(0,0,0,0); color:rgb(218,218,218); transition:transform .36s cubic-bezier(.22,1,.36,1),color .24s ease; transform:matrix(1,0,0,1,0,0); opacity:1`; rect `{0,0,1440,80}`。
- `.site-header-inner`: `width:min(calc(100% - 80px),1440px); height:100%; margin-inline:auto; display:grid; grid-template-columns:1fr auto 1fr; align-items:center; border-bottom:1px solid rgba(255,255,255,.16)`；transition `width/height .36s var(--ease-out), background-color/border-color .24s`。
- `.brand-link`: `display:inline-flex; align-items:center; gap:10px; min-height:44px; font-size:19px; font-weight:640; color:#dadada; justify-self:start`；rect `{x:40,y:18,w:86,h:44}`。
- `.brand-symbol`: `width:24px; height:24px; filter:brightness(0) invert(); transition:filter .24s`；light 时 `filter:brightness(0)`。
- `.header-actions`: `display:flex; align-items:center; gap:14px; justify-self:end`；≤900 `gap:2px`。
- `.language-toggle`: `width/height/min-width/min-height:44px; display:inline-grid; place-items:center; background:transparent; color:inherit; font-family:"Geist Mono"; font-size:11px`；rect `{x:1246,y:18,w:44,h:44}`。
- 下载键：`display:flex; align-items:center; justify-content:center; width:96px; height/min-height:36px; padding:0 14px; background:rgb(37,99,235); color:#fff; border:0; border-radius:8px; overflow:hidden; font-size:12px; font-weight:560; white-space:nowrap`；rect `{x:1304,y:22,w:96,h:36}`。
- `.menu-toggle`: `width:44px; height:44px; display:none; position:relative; place-items:center`；四个 span `5×5px; border:1px solid currentColor; transition:transform .24s var(--ease-out)`，初始位移 `(-7,-7)/(7,-7)/(-7,7)/(7,7)`。
- `.skip-link`: `position:fixed; top/left:12px; z-index:200; padding:10px 14px; background:#e7e7e7; color:#090909; transform:translateY(-160%)`; focus → `translateY(0)`。

## States and behavior
- **主题：** dark=`color:#dadada`、白底边、logo 反白；light=`color:#090909`、底边 `rgba(21,24,29,.16)`、logo 黑；blue=`color:#fff`。
- **scrolled：** inner → `backdrop-filter:blur(14px); background:rgba(11,13,16,.94); border:1px solid rgba(255,255,255,.14); border-radius:6px; width:min(100% - 32px,920px); height:58px; margin-top:11px; padding-inline:16px`。light 背景 `rgba(246,248,248,.94)`、边 `rgba(21,24,29,.14)`。
- **hidden：** `.is-hidden {transform:translateY(-110%)}`；`:focus-within {transform:translateY(0)}`。
- **下载 hover：** background `#2563eb→#1d4ed8`; `transform:none`; `::before` 执行 `button-sheen .76s var(--ease-out)`；coarse pointer/reduced-motion 关闭。header 下载键隐藏 bracket corners 与 `_` cursor。
- **语言 click：** `zh-CN↔en`，`#current-lang` 显示目标语言。
- **menu click：** `aria-expanded` 切换；span 1/4 `rotate(45deg)`，2/3 `rotate(-45deg)`。
- **focus：** skip-link 滑入；focus-within 强制 header 显示。

## Responsive evidence
- **1440：** 三列，h80，语言+下载显示，menu-toggle 隐藏。
- **≤900 / 768：** inner `grid-template-columns:1fr auto`；下载键隐藏；menu-toggle `display:grid`；scrolled `width:calc(100% - 24px); height:52px; margin-top:6px`。
- **390：** 同 ≤900；见截图。关键断点 900/680。

## reduced-motion
- 全局 `transition-duration:.01ms!important; animation-duration:.01ms!important; html{scroll-behavior:auto}`；状态仍切换，高光动画关闭。

## AgentDock mapping
- logo/字标替换 AgentDock；下载替换当前 DMG；强调色可保留蓝或采用 AgentDock coral（实现前确认）。

## Evidence gaps
- `is-scrolled/is-hidden` 精确滚动阈值未逐帧取得；只可实现已证实的状态值，不得声称精确阈值。
