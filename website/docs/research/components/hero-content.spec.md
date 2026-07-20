<!-- [skill: go-team-standards · clone-website · 组件取证规格] HeroContent：首屏文案、演示按钮、状态与响应式排版 -->
# HeroContent Specification

## Overview
- **唯一目标文件：** `src/components/sections/hero-content.tsx`
- **职责：** `.hero-inner`、eyebrow、H1、底部 demo/status/description、reveal 与双语内容。
- **Interaction model：** load/scroll reveal + hover/click/focus。
- **Builder 限制：** 只改此目标文件；不得实现 Canvas 或 section 外壳。

## Screenshots
- `./assets/hero-1440.png`
- `./assets/hero-1440-demo-hover.png`
- `./assets/hero-768.png`
- `./assets/hero-390.png`

## DOM
```html
<div class="hero-inner">
  <p class="hero-eyebrow" data-reveal>VOKIE · 会整理的 AI 语音助手</p>
  <h1 class="hero-title" data-reveal>
    <span class="hero-title-left">你只管说</span>
    <span class="hero-title-right">Vokie 帮你整理</span>
  </h1>
  <div class="hero-bottom" data-reveal>
    <div class="hero-cta">
      <button class="hero-demo-trigger">观看演示</button>
      <span class="hero-demo-status" role="status" aria-live="polite"></span>
    </div>
    <div class="hero-copy"><p class="hero-description">Vokie 把自然口述整理成可用文字，<br>也把线上线下会议变成转写、摘要与行动项。</p></div>
  </div>
</div>
```

## Exact computed styles — 1440×900
- `.hero-inner`: `display:grid; position:relative; z-index:3; grid-template-rows:auto 1fr auto; width:min(100% - 80px,1440px); height:876px; margin:0 40px; padding:108px 0 28px`；rect `{x:40,w:1360,h:876}`。
- `.hero-eyebrow`: `font-family:"Geist Mono"; font-size:12px; font-weight:520; line-height:15.6px; text-transform:uppercase; color:rgba(246,248,248,.66)`；rect `w1360,h16`；reveal transition `opacity/transform .9s cubic-bezier(.22,1,.36,1)`。
- `.hero-title`: `position:relative; z-index:4; width:1360px; font-size:68px; font-weight:570; line-height:64.6px(.95); letter-spacing:0; text-align:center; align-self:center; color:rgb(218,218,218)`；rect `h65`。
- `.hero-bottom`: `display:grid; grid-template-columns:660px 660px; gap:40px; align-items:start; padding-top:20px; border-top:1px solid rgba(255,255,255,.18)`；rect `w1360,h71`。
- `.hero-demo-trigger`: `display:flex; width:56px; height:44px; font-size:14px; color:rgb(218,218,218); opacity:.72; background:transparent; padding:0; cursor:pointer; transition:opacity .18s`。
- `.hero-demo-status`: `font-family:"Geist Mono"; font-size:11px; line-height:1; color:rgba(246,248,248,.38); white-space:nowrap; opacity:0; transform:translateX(-4px); pointer-events:none; transition:opacity .22s ease,transform .28s cubic-bezier(.22,1,.36,1)`。
- `.hero-description`: `width/max-width:480px; font-size:15px; line-height:24.75px(1.65); color:rgba(246,248,248,.68); text-align:right; margin-left:auto; text-wrap:pretty`；rect `{x:920,w:480,h:50}`。

## States and behaviors
- **reveal initial：** `html.motion-ready [data-reveal] {opacity:0; transform:translateY(32px)}`。
- **reveal visible：** `.is-visible {opacity:1; transform:translateY(0); transition:opacity/transform .9s var(--ease-out)}`；IntroCurtain 完成后由 IntersectionObserver 依次触发 eyebrow/title/bottom。
- **demo hover：** trigger opacity 从 `.72` 提升；status 加 `.is-visible` → `opacity:1; transform:translateX(0)`。
- **demo click：** 触发演示并更新 `aria-live="polite"` 状态文本。
- **focus：** button 可 Tab；状态通过 live region 播报。
- `html[lang="en"] .hero-title-right {margin-left:.22em}`。

## Responsive evidence
- **≥1536：** title 76px。
- **1440：** title 68px；bottom 两列 660/660，gap40。
- **≤1180：** title 58px；bottom gap26。
- **768 / ≤900：** inner top padding `calc(80px + 26px)`；title 52px；bottom 仍两列。
- **390 / ≤680：** inner `grid-template-rows:auto 1fr auto; padding-bottom:18px`；title 39px/lh1；bottom 单列 grid areas `"copy" "cta"`、gap18、padding-top14；description 12px/lh1.55；cta 横排 gap18。
- **≤680 且 height≤640：** inner top padding `calc(80px + 14px)`、bottom 12px；title 34px。

## reduced-motion
- `.motion-ready [data-reveal] {opacity:1; transform:none}`；全局 duration `.01ms`。内容必须首帧可读。

## Resources and verbatim text
- 字体：MiSans/Semibold（标题570）、Geist Mono（eyebrow/status）；GSAP + IntersectionObserver reveal。
- 原文：eyebrow「VOKIE · 会整理的 AI 语音助手」；H1「你只管说 Vokie 帮你整理」；按钮「观看演示」；描述「Vokie 把自然口述整理成可用文字，也把线上线下会议变成转写、摘要与行动项。」

## AgentDock mapping
- eyebrow → `AGENTDOCK · 所有 Agent，一眼看清`。
- H1 → `Agent 在工作。/ 你保持专注。`；EN `Your agents are working. / You stay in flow.`。
- demo → 刘海/notch 演示；description → `实时状态、审批与用量，都在 macOS 刘海里。`
- 首屏另需可见「下载 Mac 版」入口；内容必须由真实产品能力验证。

## Evidence gaps
- `hero-title-left/right` 精确类名与切分来自样式规则，实际 innerHTML 未逐字符导出。
- demo 点击后的完整面板流程未在本组件取证。
