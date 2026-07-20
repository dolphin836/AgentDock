<!-- [skill: clone-website · 组件取证规格] Vokie FinalCTACard/Visual → AgentDock 组件规格（仅规格，不改生产代码） -->
# Final CTA Card / Visual 规格

> 来源：https://vokie.com/ `.final-cta-card` + `.final-cta-visual`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标与 DOM

```html
<figure class="final-cta-visual" aria-hidden="true">
  <img src="/assets/final-voice-context-4fXSA-Al.png" alt=""
    width="1383" height="721" loading="lazy" decoding="async">
</figure>
<div class="final-cta-card">
  <div class="final-cta-heading">
    <p class="eyebrow">Vokie · 会整理的 AI 语音助手</p>
    <h2>现在，开口就好</h2>
  </div>
  <div class="final-cta-copy">
    <p>Vokie 接住自然表达，把它整理成当下可用、未来可调用的工作上下文。</p>
    <a class="bracket-link bracket-link-light" href="/download.html">
      <span class="bracket-corner corner-tl"></span><span class="bracket-corner corner-tr"></span>
      <span class="bracket-corner corner-bl"></span><span class="bracket-corner corner-br"></span>
      <span>下载 Vokie</span>
    </a>
    <span class="final-platforms">macOS Apple Silicon · macOS Intel · Windows x64</span>
  </div>
</div>
```

## Exact styles and right bleed

```css
.final-cta-visual{display:flex;justify-content:center;align-items:center;
  min-width:0;min-height:540px;overflow:hidden}
.final-cta-visual img{display:block;width:100%;height:auto;object-fit:contain}
.final-cta-card{display:flex;flex-direction:column;justify-content:center;min-width:0;
  min-height:540px;padding:72px 64px;background:#2563eb;border-radius:30px}
.final-cta .eyebrow{margin-bottom:28px;color:#fff}
.final-cta h2{font-size:76px;font-weight:560;line-height:1.02}
.final-cta-copy>p{max-width:520px;margin:46px 0 34px;color:#fffffff5;
  font-size:19px;line-height:1.65}
.final-platforms{display:block;margin-top:28px;color:#fff;
  font:520 12px/1.3 "Geist Mono",monospace;text-transform:uppercase}
.final-cta :focus-visible{outline:2px solid #fff;outline-offset:4px}
@media(min-width:901px){
  .final-cta-card{
    --final-cta-edge:max(var(--page-gutter),calc((100vw - var(--content-width))/2));
    width:calc(100% + var(--final-cta-edge));
    margin-right:calc(var(--final-cta-edge)*-1);
    border-radius:30px 0 0 30px;
  }
}
```

1440 时 edge=40px：卡向右贴视口边缘，不补右 padding，右直角、左 30px 圆角。h2 ≥901 被单独强制为 60px。

## Download states

```css
.bracket-link{position:relative;display:inline-flex;align-items:center;justify-content:center;
  min-height:48px;padding:0 22px;white-space:nowrap;font-size:14px;font-weight:560;
  transition:transform .24s cubic-bezier(.22,1,.36,1),color .18s ease}
.bracket-corner{position:absolute;width:9px;height:9px;border-style:solid;border-color:currentColor;
  transition:transform .24s cubic-bezier(.22,1,.36,1)}
.bracket-link:hover{transform:translate(4px)}
.bracket-link:hover .corner-tl{transform:translate(-2px,-2px)}
.bracket-link:hover .corner-tr{transform:translate(2px,-2px)}
.bracket-link:hover .corner-bl{transform:translate(-2px,2px)}
.bracket-link:hover .corner-br{transform:translate(2px,2px)}
.bracket-link[href="/download.html"]{overflow:hidden;border:0;border-radius:8px;
  background:#2563eb;color:#fff}
.final-cta .bracket-link[href="/download.html"]{background:#111}
.bracket-link[href="/download.html"] .bracket-corner{display:none}
.bracket-link[href="/download.html"]>span:last-child:after{content:"_";margin-left:.18em;
  font-family:"Geist Mono",monospace;animation:command-cursor 1.4s step-end infinite}
.bracket-link[href="/download.html"]:before{content:"";position:absolute;
  inset:-70% auto -70% -42%;width:28%;opacity:0;pointer-events:none;
  background:linear-gradient(90deg,#0000,#ffffff6b,#0000);transform:skew(-18deg)}
.bracket-link[href="/download.html"]:hover{background:#1d4ed8;transform:none}
.bracket-link[href="/download.html"]:hover:before{
  animation:button-sheen .76s cubic-bezier(.22,1,.36,1) both}
@keyframes button-sheen{
  0%{opacity:0;transform:skew(-18deg) translate(0)}18%{opacity:.9}
  to{opacity:0;transform:skew(-18deg) translate(620%)}}
@keyframes command-cursor{0%,48%{opacity:1}49%,to{opacity:0}}
```

- 默认：carbon 实心按钮、8px radius、白字、`_` 以 1.4s step 闪烁。
- hover：背景 `#1d4ed8`，无位移，斜向扫光 .76s；下载态四角隐藏。
- focus：白色 2px outline / 4px offset。粗指针下通用 hover transform 禁用。
- 通用 bracket-link 原本 hover 右移 4px、四角向外各移 2px；下载态以 `transform:none` 和隐藏 corners 覆盖。
- visual 纯装饰、不可聚焦；整节无 reveal/sticky/scrub。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---|---|---|
| card | 右出血；`72px 64px`；radius `30 0 0 30` | 无出血；`54px 40px`；30px | 无出血；`44px 24px`；22px |
| visual | min-height 540px | min-height 0 | min-height 0 |
| h2 | 60px | 76px | 48px |
| body / eyebrow | 19 / 12px | 19 / 12px | 16 / 10px |

## Reduced motion

```css
@media(prefers-reduced-motion:reduce){
  *,:before,:after{transition-duration:.01ms!important;animation-duration:.01ms!important;
    animation-iteration-count:1!important}
  .bracket-link[href="/download.html"]>span:last-child:after{opacity:1;animation:none}
  .bracket-link[href="/download.html"]:hover:before{animation:none}
}
```

`_` 常显不闪；扫光关闭；CTA 功能不变。

## Asset and AgentDock mapping

- Vokie visual：`final-voice-context-*` 1383×721、lazy/async、装饰；AgentDock 必须换成真实产品视觉。
- CTA 改为 AgentDock 真实 DMG URL 与版本（当前规格 `v0.2.4`）；首屏/收尾一致并兼容发布脚本。
- 平台行只列真实支持的 macOS 架构；卡背景可改 AgentDock 暖珊瑚强调色。
- 命令光标适合开发者气质，可保留，但必须保留 reduced-motion 降级。
