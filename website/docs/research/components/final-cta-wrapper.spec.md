<!-- [skill: clone-website · 组件取证规格] Vokie FinalCTA Wrapper → AgentDock 组件规格（仅规格，不改生产代码） -->
# FinalCTA Wrapper 规格

> 来源：https://vokie.com/ `.final-cta.dark-section`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标

只负责收尾 CTA 的暗色 section、两列装配和断点；FinalCTACard/Visual 见独立规格。

## DOM

```html
<section class="final-cta dark-section" data-header="dark">
  <div class="section-inner final-cta-layout">
    <figure class="final-cta-visual" aria-hidden="true">…</figure>
    <div class="final-cta-card">…</div>
  </div>
</section>
```

## Exact styles

```css
:root{
  --carbon:#111;--vokie-blue:#2563eb;--vokie-blue-dark:#1d4ed8;
  --page-gutter:40px;--content-width:1440px;
  --ease-out:cubic-bezier(.22,1,.36,1);
}
.section-inner{width:min(calc(100% - var(--page-gutter)*2),1440px);margin-inline:auto}
.final-cta{background:var(--carbon);color:#fff;padding:80px 0 96px}
.final-cta-layout{display:grid;
  grid-template-columns:minmax(0,1.12fr) minmax(480px,.88fr);
  align-items:stretch;gap:28px}
@media(min-width:901px){
  .final-cta-layout{align-items:start}
  .final-cta h2{font-size:60px!important}
}
```

- 左 visual 列较宽，右 card 列最小 480px；与 PrivacySection 左卡右图镜像。
- section 无背景图、伪元素或 reveal；出血由 card 子组件向右完成。

## States

- **Interaction model:** static wrapper。
- 无 scroll、sticky、reveal、hover、click；下载按钮状态属于 card 子组件。
- `data-header="dark"` 仅为全局 header 主题提示。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---:|---:|---:|
| gutter / inner | 40 / 1360px | 24 / 720px | 18 / 354px |
| layout | `minmax(0,1.12fr) minmax(480,.88fr)` | 单列 `1fr` | 单列 `1fr` |
| align / gap | start / 28px | stretch / 20px | stretch / 20px |
| section padding | `80px 0 96px` | 同基础 | `86px 0` |

≤1180：gutter 24px。≤900：单列、gap 20px。≤680：gutter 18px、section padding 86px 0。

## Reduced motion

wrapper 无动画；全局 reduce 不改变栅格和 section 几何。

## AgentDock 映射

- 作为下载收尾装配器，保持「产品视觉 → 下载卡」阅读顺序。
- 可增加稳定 `id="download"`，供顶部/页脚导航锚定。
- 下载 URL 与版本必须继续位于 HTML 文本/属性中，兼容 `scripts/package.sh` 替换；首屏与收尾地址保持一致。
