<!-- [skill: go-team-standards · clone-website · 组件取证规格] CapabilityPanel：单卡视觉、手风琴状态、插画与移动降级 -->
# CapabilityPanel Specification

## Overview
- **唯一目标文件：** `src/components/sections/capability-panel.tsx`
- **职责：** 单个 capability 卡的 DOM、配色、插画、active/aria 与移动静态展开。
- **Interaction model：** desktop click-driven accordion；mobile static expanded。
- **Builder 限制：** 只改此目标文件；不实现 section heading/scroll reveal。

## Screenshots
- 默认：`./assets/ethos-1440-default.png`
- active：`./assets/ethos-1440-active.png`
- 移动：`./assets/ethos-768.png`、`./assets/ethos-390.png`

## DOM
```html
<article class="capability-panel" data-capability="0">
  <div class="capability-surface" id="capability-card-free">
    <button class="capability-trigger" aria-expanded="false" aria-controls="capability-card-free"><span class="panel-title">自由表达</span></button>
    <h3 class="capability-mobile-heading"><span class="panel-title">自由表达</span></h3>
    <div class="capability-content" aria-hidden="false">
      <img class="capability-illustration" alt="" aria-hidden="true" loading="lazy" decoding="async">
      <p>真实地说，自由地说，Vokie 会接住你的每句话。</p>
    </div>
  </div>
</article>
```

## Exact computed styles — desktop
- `.capability-panel`: `position:relative; flex:0 0 auto; width:25%; min-width:0; height:100%; transition:width .5s cubic-bezier(.62,.16,.13,1.01) .1s`。
- active sizing：`.is-active width:40%`；容器存在 active 时其余 `width:20%`。
- `.capability-surface`: `display:flex; position:relative; flex-direction:column; align-items:center; gap:44px; width:125%; height:100%; padding:40px 20px; border-radius:20px; overflow:hidden; transition:all .5s cubic-bezier(.62,.16,.13,1.01) .1s`；active surface `width:100%`。
- 1440 默认 surface rect：`425×520px`；四块 x=`40/380/720/1060`（125% 产生重叠视觉）。
- 配色：free `bg rgb(17,17,17)/color rgb(218,218,218)`；fidelity `rgb(92,147,159)/rgb(17,17,17)`；ready `rgb(237,109,64)/rgb(17,17,17)`；persist `rgb(231,231,231)/rgb(17,17,17)`。
- `.capability-trigger`: `display:grid; place-items:center; width:min(100%,300px); min-height:0; color:inherit; text-align:center; background:transparent; padding:0; cursor:pointer`；实测 `300×31.5px`。
- `.capability-mobile-heading`: desktop `display:none`。
- `.capability-content`: `display:flex; flex:1; flex-direction:column; justify-content:space-between; align-items:center; gap:44px; width:min(100%,300px); min-width/min-height:0; visibility:visible; opacity:1; text-align:center`。
- content `p`: `width:70%; max-width:300px; margin-inline:auto; font-family:"Geist Mono"; font-size:12px; line-height:1.25; text-transform:uppercase; text-align:center; text-wrap:pretty`。
- illustration：`width:100%; max-width:300px; height:205px; object-fit:contain; object-position:center; opacity:.94; transform:translateY(var(--illustration-offset-y)) scale(1.5,1.34); transform-origin:50% center; pointer-events:none; user-select:none`。
- illustration offset：free23 / fidelity34 / ready35 / persist17px；2/3/4 `filter:invert()`。

## States and behaviors
- **click active：** 25→40%，siblings 25→20%；surface 125→100%；transition `.5s var(--ease-structural) .1s`。
- `aria-expanded` 与 active 同步；content `aria-hidden` 同步；`aria-controls` 指向 surface id。
- **hover：** 无独立变色/缩放证据。
- **focus：** trigger 用全局 focus-visible。
- **no-JS：** panels 纵向；每卡 `width:100%; min-height:480px`；trigger隐藏；mobile heading显示；content全部可见。

## Responsive evidence
- **1440：** 手风琴 25/40/20%；height520。
- **≤767 / 768：** `width:100%!important; height:auto; min-height:480px; transition:none`；surface `width:100%; min-height:480px; gap:22px; padding:40px 20px 20px`；trigger隐藏；mobile heading grid；content `gap:22px;width:100%;max-width:none;padding:0`。
- **390 / ≤680：** illustration offsets 全0、`width/max-width:100%`；content p `width/max-width:100%`；旧 trigger 规则 `min-height:84px;padding:20px` 因 ≤767 display:none 不可见。

## reduced-motion
- transition 压至 `.01ms`；click/aria 功能保留。移动本来 `transition:none`。

## Assets and verbatim content
- free `/assets/free-expression-*.png`；fidelity `/assets/faithful-editing-*.png`；ready `/assets/ready-now-*.png`；persist 文件名未知。
- 原文：自由表达—真实地说，自由地说，Vokie 会接住你的每句话；忠实整理—无论即时输入还是录音整理，都忠于你的本意与事实，不猜测，不漂移；当下有用—说完即可使用：一段顺眼的输入文本、一份清晰的纪要或摘要；持续可用—每次记录都沉淀在拾忆，随时供你和 Agent 调用。

## AgentDock mapping
- free→看见状态（Claude Code/Codex/Cursor）；fidelity→减少打断；ready→及时响应（Allow/Review/Deny）；persist→返回工作区。
- 插画替换为 AgentDock 真实产品图；保留四配色、20px 圆角与 Mono 正文。

## Evidence gaps
- persist 插画精确文件名未取得，禁止猜测。
- active 内容的 `aria-hidden` 原截图为 false；精确切换逻辑需按可见性实现，不得仅靠颜色。
