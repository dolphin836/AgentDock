<!-- [skill: go-team-standards · clone-website · 组件取证规格] CapabilitySection：Ethos 外壳、标题与 reveal-band 响应式 -->
# CapabilitySection Specification

## Overview
- **唯一目标文件：** `src/components/sections/capability-section.tsx`
- **职责：** `section#product`、heading、panel 容器与滚动 reveal-band。
- **Interaction model：** scroll-driven reveal；不持有单卡 click 状态。
- **Builder 限制：** 只改此目标文件；CapabilityPanel 作为 children。

## Screenshots
- `./assets/ethos-1440-default.png`
- `./assets/ethos-768.png`
- `./assets/ethos-390.png`

## DOM
```html
<section class="ethos light-section reveal-band" id="product" data-header="light">
  <div class="section-inner">
    <div class="section-heading ethos-heading" data-reveal>
      <p class="eyebrow">01 / 从说到可用</p>
      <h2>想到什么，就说什么。<br>剩下的交给 Vokie</h2>
      <p>不用先组织措辞，也不用为了工具改变说话方式。</p>
    </div>
    <div class="capability-panels" id="capability-panels"><!-- CapabilityPanel children --></div>
  </div>
</section>
```

## Exact computed styles — 1440×900
- `section#product`: `display:block; position:relative; width:1440px; background:rgb(218,218,218); color:rgb(9,9,9); padding:150px 0 128px; border-radius:20px 20px 0 0; overflow:clip; opacity:1`。
- reveal 动态内联 `clip-path:inset(0 X% 0 0)`；捕获值 `X=95.4023%`，完成值 `0%`。
- `.section-inner`: `width:min(100% - 80px,1440px); margin-inline:auto`；rect `w1360`。
- `.ethos-heading`: `display:grid; grid-template-columns:1.4fr .6fr; align-items:end; gap:64px; margin-bottom:76px`。
- `.eyebrow`: `grid-column:1/-1; margin-bottom:-24px; color:#535353; font-family:"Geist Mono"; font-size:12px; font-weight:520; line-height:1.3; text-transform:uppercase`。
- `h2`: `max-width:820px; font-weight:560; line-height:.98`；1440 computed `font-size:30px`，胜出规则 `@media(min-width:901px){body main h2{font-size:30px!important}}`；基础规则 60px。
- heading 描述：`max-width:420px; color:#535353; font-size:19px; line-height:1.7`。
- `.capability-panels`: `display:flex; justify-content:center; gap:0; width:1360px; height:clamp(520px,940px - 30vw,560px)`；1440 computed `height:520px`。

## States and behavior
- **section scroll reveal：** `.reveal-band` clip-path 从 `inset(0 95.4023% 0 0)` 向 `inset(0 0% 0 0)`；GSAP ScrollTrigger，精确进度映射未知。
- **heading reveal：** `data-reveal` 初始 `opacity:0; translateY(32px)`，visible → `opacity:1; transform:none`，`.9s var(--ease-out)`。
- **header theme：** `data-header="light"`。
- section 无 click/hover/focus；子卡负责。

## Responsive evidence
- **1440：** padding150/128；1.4/.6 heading；panels 横向 1360×520。
- **≤900 / 768：** heading 单列 `grid-template-columns:1fr; gap:20px`；eyebrow margin-bottom 0。
- **≤767 / 768：** panels `flex-direction:column; gap:20px; height:auto`。
- **≤680 / 390：** section padding `96px 0`; heading margin-bottom52；h2 38px/lh1.02；eyebrow 10px；描述16px。
- 特殊证据：681–900 的基础 h2 可为60px；≥901 被 `30px!important` 覆盖。

## reduced-motion
- heading 直显；全局过渡 `.01ms`；reveal-band 应直接完成，不阻塞内容。

## Assets and verbatim text
- 字体 MiSans + Geist Mono；section 自身无图片。
- 原文：`01 / 从说到可用`；`想到什么，就说什么。剩下的交给 Vokie`；`不用先组织措辞，也不用为了工具改变说话方式。`

## AgentDock mapping
- eyebrow → `01 / 专注（Focus）`。
- title → `知道谁需要你，无需逐个窗口查看。`
- description → `一个安静的界面，看清每个 Agent 的状态。`
- 保留浅纸底、20px 顶圆角、滚动横向揭示与 responsive 堆叠。

## Evidence gaps
- clip-path 与 scroll 的精确 GSAP scrub/trigger 范围未逐帧取得。
- clamp 在 1440 以外仅有 CSS 公式与截图，未逐视口提取 computed 高度。
