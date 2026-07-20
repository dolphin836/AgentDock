<!-- [skill: clone-website · 组件取证规格] Vokie ContextWorld Wrapper/Backdrop → AgentDock 组件规格（仅规格，不改生产代码） -->
# ContextWorld Wrapper / Backdrop 规格

> 来源：https://vokie.com/ `#context.context-world`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标

负责 ContextWorld 的暗色外壳、5 条滚动竖线、两个 grid 章节的装配边界及愿景收尾；热词卡和 integrations 卡分别见独立规格。

## DOM

```html
<section id="context" class="context-world dark-section" data-header="dark">
  <div class="context-backdrop" aria-hidden="true">
    <span></span><span></span><span></span><span></span><span></span>
  </div>
  <div id="personalization" class="context-chapter section-inner">…</div>
  <div id="agent" class="context-chapter context-chapter-reverse section-inner">…</div>
  <div class="vision-statement section-inner" data-reveal>
    <p class="eyebrow">我们的方向</p>
    <h3>让说过的话，继续为你工作</h3>
    <p>未来，Vokie 希望成为所有 Agent 获取个人语音上下文的基础入口。</p>
  </div>
</section>
```

## Exact styles

```css
:root{
  --carbon:#111; --paper:#dadada; --line-dark:#dadada33;
  --page-gutter:40px; --content-width:1440px;
  --ease-out:cubic-bezier(.22,1,.36,1);
}
.section-inner{width:min(calc(100% - var(--page-gutter)*2),1440px);margin-inline:auto}
.context-world{position:relative;overflow:clip;background:var(--carbon);color:var(--paper)}
.context-backdrop{position:absolute;inset:0;display:grid;grid-template-columns:repeat(5,1fr);
  opacity:.34;pointer-events:none}
.context-backdrop span{transform-origin:top;transform:scaleY(.2);
  border-right:1px solid #f6f8f814}
.context-chapter{position:relative;z-index:1;display:grid;grid-template-columns:.82fr 1.18fr;
  gap:90px;padding:160px 0 100px}
.context-chapter+.context-chapter{border-top:1px solid var(--line-dark)}
.context-chapter-reverse{grid-template-columns:1.18fr .82fr}
.context-chapter-reverse .context-copy{grid-area:1/2}
.context-chapter-reverse .context-stack{grid-area:1/1}
.vision-statement{position:relative;z-index:1;text-align:center;
  border-top:1px solid var(--line-dark);padding:120px 0 160px}
.vision-statement .eyebrow{color:#f6f8f870;margin-bottom:28px}
.vision-statement h3{max-width:1120px;margin-inline:auto;font-size:70px;font-weight:560;line-height:1}
.vision-statement>p:last-child{max-width:680px;margin:36px auto 0;color:#f6f8f894;
  font-size:18px;line-height:1.7}
```

## States and interaction model

- **Model:** scroll-driven GSAP scrub + IntersectionObserver reveal；无 click/hover。
- 竖线 CSS 初始 `scaleY(.2)`；滚动中实测从左到右为 `1 / .91 / .782 / .654 / .526`，`transform-origin:top`。
- 内容均 `z-index:1` 覆盖绝对定位 backdrop；section `overflow:clip` 裁切背景与 sticky 溢出，不做视口出血。
- 愿景默认 `.motion-ready [data-reveal]{opacity:0;transform:translateY(32px)}`；进入视口后 `.is-visible` → `opacity:1;transform:translateY(0)`，`opacity/transform .9s var(--ease-out)`。
- 无 JS 时 `[data-reveal]{opacity:1;transform:none}`。
- ≥901 全局 `body main h3{font-size:30px!important}`，因此 1440 实测愿景 h3 为 30px，而非基础 70px。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---:|---:|---:|
| gutter / inner | 40 / 1360px | 24 / 720px | 18 / 354px |
| chapter grid | `.82fr 1.18fr`；reverse `1.18fr .82fr` | 单列；reverse grid-area 恢复 auto | 单列 |
| gap / padding | 90px / `160 0 100` | 54px / 基础 padding | 50px / `96 0 72` |
| vision padding | `120 0 160` | 同基础 | `82 0 100` |
| vision h3 实测 | 30px | 70px | 40px |

≤1180：`--page-gutter:24px`、chapter gap 54px。≤900：chapter 单列，reverse 子项恢复自然顺序。≤680：gutter 18px、上述移动值。

## Reduced motion

```css
@media(prefers-reduced-motion:reduce){
  html{scroll-behavior:auto}
  *,:before,:after{transition-duration:.01ms!important;animation-duration:.01ms!important;
    animation-iteration-count:1!important}
  .motion-ready [data-reveal]{opacity:1;transform:none}
}
```

不注册 GSAP scroll-scrub，竖线保持静态 `scaleY(.2)`；愿景直接可见。

## AgentDock 映射

- 外壳承载 AgentDock「本地集成」长章节：hotword/history grid → integrations grid → 愿景。
- 5 条竖线可复用为暗色叙事底纹，不含 Vokie 品牌资产。
- 愿景映射为「让每个 agent 的状态，继续为你工作」；不得扩展为当前产品未实现的自动化承诺。
