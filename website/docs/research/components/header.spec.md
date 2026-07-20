<!-- [skill: go-team-standards · clone-website · 组件取证规格] Header wrapper：仅装配 HeaderShell、DesktopNav 与既有 MobileMenu -->
# Header Wrapper Specification

## Overview
- **唯一目标文件：** `src/components/layout/header.tsx`
- **职责：** 只装配 `HeaderShell`、`DesktopNav`、`MobileMenu`；持有语言与菜单开合共享状态，不实现子组件视觉细节。
- **Interaction model：** composition + click state delegation。
- **Complexity budget：** builder 只改上述一个目标文件；不得同时创建/修改子组件。
- **证据来源：** `https://vokie.com/`，2026-07-20，Browser MCP。

## Builder dependencies
- `header-shell.spec.md` → `src/components/layout/header-shell.tsx`
- `desktop-nav.spec.md` → `src/components/layout/desktop-nav.tsx`
- `mobile-menu.spec.md` → `src/components/layout/mobile-menu.tsx`
- 可选既有组件：`src/components/layout/skip-link.tsx`

## Reference screenshots
- `./assets/header-1440-default.png`
- `./assets/header-1440-scrolled.png`
- `./assets/header-1440-nav-hover.png`
- `./assets/header-768-default.png`
- `./assets/header-390-default.png`

## Composition contract
```tsx
<>
  <SkipLink href="#main-content" />
  <HeaderShell
    theme={headerTheme}
    isScrolled={isScrolled}
    isHidden={isHidden}
    brand={brand}
    actions={actions}
  >
    <DesktopNav items={navItems} activeHref={activeHref} />
  </HeaderShell>
  <MobileMenu open={menuOpen} items={navItems} onNavigate={closeMenu} />
</>
```

## Shared state and events
- `menuOpen`: `#menu-toggle` click 切换；同步 `aria-expanded`、MobileMenu `aria-hidden` 与 `inert`。
- `language`: 中/英切换；`document.documentElement.lang` 在 `zh-CN` / `en` 间切换，`#current-lang` 显示目标语言。
- `headerTheme`: 由当前 section 的 `data-header="dark|light|blue"` 提供；具体滚动监听与视觉值归 `HeaderShell`。
- `activeHref`: 当前 section 锚点；导航指示器计算归 `DesktopNav`。

## DOM ownership
- wrapper 拥有：`SkipLink`、共享状态、props 传递、三个子组件的顺序。
- `HeaderShell` 拥有：`header#site-header`、品牌、actions、语言键、下载键、menu-toggle、滚动/主题类。
- `DesktopNav` 拥有：桌面 `<nav>`、链接、`.nav-indicator`。
- `MobileMenu` 拥有：全屏移动菜单。

## Responsive assembly
- **1440：** HeaderShell 内显示 DesktopNav + 语言键 + 下载键；MobileMenu 关闭且不可交互。
- **768 / 390：** DesktopNav 与 header 下载键由子组件 CSS 隐藏；menu-toggle 出现；MobileMenu 可打开。
- 精确断点与 computed 值分别见 `header-shell.spec.md`、`desktop-nav.spec.md`、`mobile-menu.spec.md`。

## reduced-motion
- wrapper 不实现动画；仅向子组件传状态。
- 子组件按 `prefers-reduced-motion` 将过渡缩至 `.01ms`，功能状态仍切换。

## Content map
- 品牌：Vokie → AgentDock；首页锚点 `#top`。
- 导航：听写/记录/Agent/隐私 → 状态/审批/集成/隐私；锚点 `#status/#approval/#integrations/#privacy`。
- 下载：`/download.html` → 当前 AgentDock DMG URL。
- 跳过链接：`#main-content`；中英文均需完整。

## Evidence gaps
- `is-scrolled`、`is-hidden` 的精确 scrollY 阈值未取得；不得在 wrapper 中猜测，交由 HeaderShell 实现时按其规格标注。
- 本 wrapper 不重复 computed CSS；所有原证据已迁移至两个子规格。
