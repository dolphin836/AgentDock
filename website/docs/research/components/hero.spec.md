<!-- [skill: go-team-standards · clone-website · 组件取证规格] Hero wrapper：仅装配 HeroContent 与 HeroCanvas -->
# Hero Wrapper Specification

## Overview
- **唯一目标文件：** `src/components/sections/hero.tsx`
- **职责：** section 外壳、层级、HeroContent/HeroCanvas 装配；不实现内容或 WebGL 内部。
- **Interaction model：** composition + section-level scroll context。
- **Complexity budget：** builder 只改此目标文件。
- **证据来源：** `https://vokie.com/`，2026-07-20，Browser MCP。

## Builder dependencies
- `hero-content.spec.md` → `src/components/sections/hero-content.tsx`
- `hero-canvas.spec.md` → `src/components/sections/hero-canvas.tsx`

## Screenshots
- `./assets/hero-1440.png`
- `./assets/hero-768.png`
- `./assets/hero-390.png`
- `./assets/hero-1440-demo-hover.png`

## DOM and ownership
```tsx
<section id="top" className="hero dark-section" data-header="dark">
  <HeroCanvas />
  <HeroContent />
</section>
```
- wrapper 仅拥有 `section#top.hero.dark-section`。
- HeroCanvas 拥有 canvas、WebGL 生命周期与 reduced-motion 降级。
- HeroContent 拥有 eyebrow、h1、demo/status、description 与 reveal。

## Exact section computed evidence — 1440×900
```css
position:relative; overflow:hidden; isolation:isolate;
height:calc(100svh - 24px); min-height:580px;
background:rgb(17,17,17); color:rgb(218,218,218);
```
- 实测 rect：`{w:1440,h:876}`。
- `::after`: `content:""; position:absolute; inset:auto 0 0; height:1px; background:rgba(255,255,255,.18); z-index:2`。

## Section behavior
- 高度独占首屏；向下进入 `#product` 时 Header 主题 dark→light。
- section 本身无 click/hover/focus；事件由 HeroContent 处理。
- canvas 在内容底层，内容在 z-index 3/4。

## Responsive wrapper evidence
- **1440：** `height:calc(100svh - 24px); min-height:580px`。
- **768：** 同 section 高度模型。
- **≤680 / 390：** `height:calc(100svh - 18px); min-height:620px`。
- **≤680 且高度≤640：** `height:calc(100svh - 10px); min-height:0`。

## reduced-motion
- wrapper 不驱动动画；保留可读首屏。
- Content 直显、Canvas 停止/静帧的要求分别见子规格。

## AgentDock mapping
- section id 保持 `#top`，主题保持 dark。
- 内容替换、下载/演示入口见 `hero-content.spec.md`；画布意象见 `hero-canvas.spec.md`。

## Evidence gaps
- wrapper 无新增猜测；原 evidence gaps 已迁移到对应子规格。
