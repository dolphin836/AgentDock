<!-- [skill: clone-website · 组件取证规格] Vokie PrivacySection Wrapper → AgentDock 组件规格（仅规格，不改生产代码） -->
# PrivacySection Wrapper 规格

> 来源：https://vokie.com/ `#privacy.privacy-section`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标

只负责暗色 section、容器栅格、左右子组件装配和断点；PrivacyCard/Visual 见独立规格。

## DOM

```html
<section id="privacy" class="privacy-section dark-section" data-header="dark">
  <div class="section-inner privacy-layout">
    <div class="privacy-card">…</div>
    <figure class="privacy-visual" aria-hidden="true">…</figure>
  </div>
</section>
```

## Exact styles

```css
:root{
  --carbon:#111;--ink:#090909;--paper:#dadada;
  --page-gutter:40px;--content-width:1440px;
}
.section-inner{width:min(calc(100% - var(--page-gutter)*2),1440px);margin-inline:auto}
.privacy-section{background:var(--carbon);color:#fff;padding:112px 0 64px}
.privacy-layout{display:grid;
  grid-template-columns:minmax(480px,.88fr) minmax(0,1.12fr);
  align-items:center;gap:28px}
```

- 左列最小 480px；右列可压缩到 0；两列垂直居中。
- section 自身不出血；子卡仅在 ≥901 通过负 margin 向左出血，body `overflow-x:clip` 兜底。
- 无背景图、渐变、伪元素或叠加层。

## States

- **Interaction model:** static wrapper。
- 无 reveal、sticky、scrub、hover、click；主题通过 `data-header="dark"` 告知全局 header。
- wrapper 无可聚焦节点；子组件焦点规则见 PrivacyCard/Visual。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---:|---:|---:|
| gutter / inner | 40 / 1360px | 24 / 720px | 18 / 354px |
| grid | `minmax(480,.88fr) minmax(0,1.12fr)` | `1fr 1.2fr` | `1fr` |
| gap | 28px | 20px | 30px |
| section padding | `112px 0 64px` | 同基础 | `86px 0` |

≤1180：gutter 24px。≤900：后置规则实际覆盖为 `1fr 1.2fr`，不是单列；eyebrow 可跨 `1/-1`。≤680：gutter 18px，才真正改为单列、gap 30px。

## Reduced motion

wrapper 无动画。全局 reduce 将所有 transition/animation 压到 `.01ms`，不改变布局、栅格或出血规则。

## AgentDock 映射

- 作为 AgentDock 隐私章节装配器，保持「暗色环境 + 浅卡承诺 + 右侧边界图」。
- 稳定锚点使用 `id="privacy"`，供顶部/页脚导航跳转。
- 不在 wrapper 层加入装饰动画，维持 `PRODUCT.md` 的安静、可信气质。
