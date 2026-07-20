<!-- [skill: clone-website · 组件取证规格] Vokie Footer → AgentDock 组件规格（仅规格，不改生产代码；所有数值来自 https://vokie.com/ 实测） -->
# Footer 组件规格（Vokie → AgentDock）

> 来源：https://vokie.com/ `<footer id="footer" class="site-footer">`
> 采集视口：1440×900 / 768×1024 / 390×844；`prefers-reduced-motion: no-preference`
> 采集方式：Browser MCP 读取生产 `main-q5IdSwQt.css` + DOM + computed style。仅规格研究，不改生产代码。

## 0. 组件定位

站点页脚：四列栅格（品牌 / 导航 / 联系 / 版权跨列）。安静、克制，无大标题、无 CTA，是全站信息密度最低的一节。

## 1. DOM 结构

```html
<footer class="site-footer" id="footer" data-header="dark">
  <div class="section-inner footer-layout">
    <div class="footer-brand">
      <img src="/vokie-symbol.svg" alt="" width="32" height="32">   <!-- 反白 logo -->
      <strong>Vokie</strong>
      <p>表达属于用户，整理交给 Vokie。</p>
    </div>
    <nav class="footer-nav" aria-label="页脚导航">
      <a href="/voice-input/">听写</a>
      <a href="/meeting-notes/">记录</a>
      <a href="/agent-skills/">Agent</a>
      <a href="/privacy/">隐私</a>
      <a href="/faq/">常见问题</a>
      <a href="/download.html">下载 Vokie</a>
    </nav>
    <div class="footer-contact">
      <a href="/cdn-cgi/l/email-protection#…"><span class="__cf_email__">[email protected]</span></a>
      <a href="https://discord.gg/WRy2xRrWCw" target="_blank" rel="noopener noreferrer">Discord</a>
      <img class="footer-contact-qr" src="/vokie-contact-qr.png" alt="Vokie 联系二维码" width="293" height="329" loading="lazy" decoding="async">
    </div>
    <p class="footer-legal">© 2026 Vokie · 使用 MiSans 字体</p>
  </div>
</footer>
```
- 四个直接子块：`.footer-brand` / `.footer-nav` / `.footer-contact` / `.footer-legal`（版权跨全列）。
- 品牌 SVG 与 `alt=""`（装饰，紧邻 `<strong>Vokie</strong>` 文字商标）。
- 联系区：混淆邮箱（Cloudflare）+ Discord 外链（带 `rel="noopener noreferrer"`）+ 二维码图（有真实 `alt`）。
- 导航 href 指向**独立子页**（`/voice-input/` 等），非锚点——与顶部导航的 `#voice` 锚点不同。
- 无 `data-reveal`（静态）。

## 2. 设计令牌

```css
--carbon:#111;         /* 页脚背景 */
--paper:#dadada;       /* 文本主色 */
--line-dark:#dadada33; /* 顶部分隔线 & 版权上边线 */
--page-gutter:40px→24px(≤1180)→18px(≤680);
--content-width:1440px;
/* 文本颜色多用带 alpha 的 #f6f8f8xx */
```

## 3. 背景 / 几何 / 出血

```css
.site-footer{ background:var(--carbon); color:var(--paper);
  border-top:1px solid var(--line-dark); padding:70px 0 34px; }
```
- **不出血**：所有内容在 `.section-inner`（`min(100% - gutter*2, 1440px)`，居中）内。
- 顶部 1px `--line-dark` 分隔线是与上方 FinalCTA 的唯一分界（两者都是 carbon 底）。
- 版权行 `.footer-legal` 上方再有一条 1px 分隔线并跨全列。

## 4. 布局（桌面 1440）

```css
.footer-layout{ display:grid; grid-template-columns:1.1fr .8fr .7fr; gap:70px; }
.footer-brand img{ width:32px; height:32px; margin-bottom:18px;
  filter:brightness(0) invert(); }                 /* SVG 反白为亮色 */
.footer-brand strong{ display:block; font-size:28px; font-weight:620; }
.footer-brand p{ margin-top:16px; color:#f6f8f885; }
.footer-nav,.footer-contact{ display:flex; flex-direction:column; align-items:flex-start;
  gap:13px; font-size:14px; }
.footer-nav a,.footer-contact a{ color:#f6f8f899; min-height:30px; padding:0;
  background:0 0; cursor:pointer; transition:color .16s; }
.footer-contact-qr{ display:block; width:164px; height:auto; margin-top:-18px; } /* 负 margin 上提，贴齐链接 */
.footer-legal{ grid-column:1/-1; padding-top:34px; border-top:1px solid var(--line-dark);
  color:#f6f8f85c; font-family:Geist Mono,monospace; font-size:11px; }
```
- 三列不等宽（1.1 : 0.8 : 0.7），列间 70px；版权第四行跨全列。
- 品牌栏是唯一竖排块（logo → 文字商标 → tagline）。
- 二维码 `margin-top:-18px` 上移，与上方两条链接视觉贴齐。

## 5. 交互状态

- **链接 hover**（导航 + 联系）：
  ```css
  .footer-nav a:hover,.footer-contact a:hover{ color:#fff; } /* #f6f8f899 → #fff，transition color .16s */
  ```
  仅颜色渐亮，无位移/下划线。
- **触达**：链接 `min-height:30px`（桌面）；移动端见 §6（会更大）。
- **focus-visible**：沿用全局 `outline:2px solid var(--vokie-blue); outline-offset:4px`。
- Discord 外链新窗口打开（`target="_blank" rel="noopener noreferrer"`）。
- 二维码图不可聚焦、无交互。整节无 reveal/sticky/scrub/自动动效。

## 6. 响应式（1440 / 768 / 390 实测）

| 维度 | 1440 | 768（≤900）| 390（≤680）|
|---|---|---|---|
| `--page-gutter` | 40 | 24 | 18 |
| `.section-inner` 宽 | 1360px | 720px | 354px |
| `.footer-layout` 栅格 | `1.1fr .8fr .7fr`，gap 70px | **`1fr 1fr`**（两列），`.footer-brand` 跨全列（`grid-column:1/-1`）| **单列 `1fr`**，gap 38px |
| `.footer-nav` / `.footer-contact` | 竖排 flex | 竖排 flex | **转 `display:grid; 1fr 1fr`**（两列网格）|
| `.footer-contact-qr` | 164px，`margin-top:-18px` | 同左 | `grid-column:1/-1`，宽 **150px** |
| `.footer-legal` | 11px，跨全列 | 11px | 11px（未随 eyebrow 缩到 10px，保持 11px）|
| `.footer-brand strong` | 28px | 28px | 28px |

- 768：三列→两列，品牌块独占首行。
- 390：整体单列；但导航与联系各自内部变成 2 列网格，二维码跨两列。

## 7. reduced-motion

页脚唯一动效是链接 `color .16s` 过渡；在全局 reduced-motion 块下被压到 `.01ms`（瞬时变色）。无 `data-reveal`、无动画，复刻零额外处理。

## 8. 资源清单

| 资源 | 用途 | 语义 | 备注 |
|---|---|---|---|
| `/vokie-symbol.svg` | 品牌符号 | 装饰 `alt=""` | `filter:brightness(0) invert()` 反白，32×32 |
| `/vokie-contact-qr.png` | 联系二维码 | 真实 `alt="Vokie 联系二维码"` | 293×329，显示 164px(桌面)/150px(≤680)|
| 邮件链接 | 联系邮箱 | Cloudflare email-protection 混淆 | |
| Discord 外链 | 社群 | `rel="noopener noreferrer"` | |
| 字体 `Geist Mono` | 版权行 | — | 11px |

## 9. AgentDock 页脚内容映射（本组件承载「footer 内容映射」）

保留四块结构（品牌 / 导航 / 联系 / 版权），按 AgentDock 真实信息替换：

- **footer-brand**：AgentDock 符号（反白）+ `AgentDock` 文字商标 + tagline（如「Agent 在工作，你保持专注。」）。
- **footer-nav**：映射到 AgentDock 章节/页面锚点——实时状态、审批、用量、返回工作区、集成、隐私、下载。设计规范的稳定锚点为 `status / approval / usage / return / integrations / privacy / download`。可用锚点（`#status` 等）或独立页，二选一保持一致。
- **footer-contact**：换成 AgentDock 的真实联系入口（反馈邮箱 / 社群）；若无二维码则移除该图，不要保留 Vokie 素材。**遵守铁律 12/隐私红线：不要放任何真实个人邮箱/PII 到静态源码**，用产品公共邮箱或反馈页。
- **footer-legal**：`© 2026 AgentDock`（版权年份 + 字体署名按实际）。设计规范中文正文优先 MiSans/苹方，可保留字体署名或去除。
- **克制原则**：`PRODUCT.md` 反例明确排除「无关推广 / 公开 admin 链接」——AgentDock 页脚**不得**放 admin 页链接，保持信任导向。
- **无障碍**：`nav` 保留 `aria-label`；外链保留 `rel="noopener noreferrer"`；装饰 logo `alt=""`，功能性图片（二维码类）给真实 `alt`。

> 复用清单：`.footer-layout` 四块不等宽栅格（桌面 3+1 → 768 2 列 → 390 单列且导航内嵌 2 列）、反白 logo、hover 变色链接、跨列版权行。纯结构与通用样式，替换品牌与链接即可。
