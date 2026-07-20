<!-- [skill: clone-website · 组件取证规格] Vokie MemorySection → AgentDock 组件规格（仅规格，不改生产代码；所有数值来自 https://vokie.com/ 实测） -->
# MemorySection 组件规格（Vokie → AgentDock）

> 来源：https://vokie.com/ `<section id="memory" class="memory-section dark-section">`
> 采集视口：1440×900 / 768×1024 / 390×844；`prefers-reduced-motion: no-preference`
> 采集方式：Browser MCP 读取生产 `main-q5IdSwQt.css` + DOM + computed style。仅规格研究，不改生产代码。

## 0. 组件定位

「07 / 拾忆」：拾忆是 Vokie 内置 AI Chat，可对语音历史（录音/转写/总结）提问回看。结构极简 —— 一段两列（文案 + 产品截图）。是全站最轻的一节，适合迁移为 AgentDock 的**状态历史 / 时间线**叙事（见 §7）。

## 1. DOM 结构

```html
<section class="memory-section dark-section" id="memory" data-header="dark">
  <div class="section-inner memory-layout">
    <div class="section-heading" data-reveal>
      <p class="eyebrow">07 / 拾忆</p>
      <h2>和你的语音历史对话</h2>
      <p>拾忆是 Vokie 内置的 AI Chat。把录音、转写和总结加入上下文，继续提问、回看和梳理。</p>
    </div>
    <div class="media-slot memory-media-slot has-product-media" data-media-slot="memory-chat">
      <img class="product-media" src="/product-media/memory-chat.webp" alt="拾忆 AI 对话界面" loading="lazy" decoding="async">
    </div>
  </div>
</section>
```
- 只有两个子块：左 `.section-heading`（含 eyebrow / h2 / 描述），右 `.memory-media-slot`（产品截图）。
- `.section-heading` 带 `data-reveal`（整块入场）；截图槽**无** `data-reveal`。
- 图片有真实 `alt`（非装饰）。

## 2. 设计令牌

```css
--carbon:#111;   /* section 背景（.memory-section 显式 background:var(--carbon)）*/
--paper:#dadada; /* 文本主色 */
--page-gutter:40px→24px(≤1180)→18px(≤680);
--content-width:1440px;
--ease-out:cubic-bezier(.22,1,.36,1);
```

## 3. 背景 / 出血 / 几何

```css
.memory-section{ background:var(--carbon); color:var(--paper); padding:150px 0; }
```
- **不出血**：内容全部收敛在 `.section-inner`（`min(100% - gutter*2, 1440px)`，居中）。与上一节 `#context`、下一节 `#privacy` 同为 `dark-section`，视觉上连续暗底、无分隔线。
- 截图槽本身在 `has-product-media` 下背景色 `#050607`（近黑，比 section 更深），形成轻微「显示屏」层次：
```css
.media-slot{ position:relative; border:1px solid var(--line-light); background:var(--paper-pure);
  border-radius:20px; overflow:hidden; }         /* 通用槽 */
.has-product-media{ background:#050607; min-height:0; }
.has-product-media:before,.has-product-media:after{ display:none; } /* 关掉通用槽的四角装饰 */
.product-media{ position:absolute; inset:0; width:100%; height:100%;
  object-fit:contain; background:#050607; display:block; }
```

## 4. 布局（桌面 1440）

```css
.memory-layout{ display:grid; grid-template-columns:.78fr 1.22fr;
  align-items:center; gap:84px; }
.memory-layout .eyebrow{ color:#f6f8f87a; margin-bottom:28px; }
.memory-layout .section-heading h2{ font-size:54px; }          /* 基础值 */
.memory-layout .section-heading > p:last-child{ color:#f6f8f89e; max-width:520px; margin-top:30px; }
.memory-media-slot{ aspect-ratio:2144/1546; width:90%; justify-self:center;
  background:0 0; border:0; }                                    /* 覆盖通用 media-slot 的描边/背景 */
.memory-media-slot .product-media{ object-fit:cover; background:0 0; }
```
- 左窄右宽（0.78 : 1.22），垂直居中对齐。
- 截图槽固定宽高比 `2144/1546 ≈ 1.387`，占列宽 90%、水平居中；`object-fit:cover`（区别于通用 `.product-media` 的 contain）。
- 注意 h2 桌面实测被 `@media(min-width:901px){body main h2{font-size:30px!important}}` 压到 **30px**（基础 54px 只在 681–900 生效）。

## 5. 交互状态

- **hover / click**：无。本节没有按钮、tab、可点媒体，纯展示。
- **scroll —— reveal**：仅 `.section-heading[data-reveal]` 入场：
  ```css
  .motion-ready [data-reveal]{ opacity:0; transform:translateY(32px); }
  .motion-ready [data-reveal].is-visible{ opacity:1; transform:translateY(0);
    transition:opacity .9s var(--ease-out), transform .9s var(--ease-out); }
  ```
  截图槽无入场动画（始终可见）。
- 无 sticky、无 scrub、无自动轮播。

## 6. 响应式（1440 / 768 / 390 实测）

| 维度 | 1440 | 768 | 390 |
|---|---|---|---|
| `--page-gutter` | 40 | 24 | 18 |
| `.section-inner` 宽 | 1360px | 720px | 354px |
| `.memory-layout` 栅格 | `.78fr 1.22fr`，gap 84px | **单列** `1fr`，gap 20px（≤900）| 单列，gap 20px |
| `.memory-section` padding | `150px 0` | `96px 0`（≤767 `.memory-section` 归入 `96px 0`）| `96px 0` |
| `.memory-media-slot` | 宽 90%，居中 | `width:90%; min-height:0`（≤680 显式）| 同左，单列下满宽内 90% |
| h2 实测 | **30px**（!important）| 54px | **38px**（≤680 `.memory-layout h2` = 38px）|
| eyebrow | 12px（≤680→10px），色 `#f6f8f87a` | 12px | 10px |

≤900 起两列塌成单列：文案在上、截图在下，间距收紧到 20px。

## 7. reduced-motion

```css
@media(prefers-reduced-motion:reduce){
  .motion-ready [data-reveal]{ opacity:1; transform:none; }  /* 标题块直接可见 */
  *,:before,:after{ transition-duration:.01ms!important; animation-duration:.01ms!important; }
}
```
本节除 reveal 外无其他动效，reduced-motion 下等价于静态渲染。复刻零额外处理。

## 8. 资源清单

| 资源 | 用途 | 语义 | 备注 |
|---|---|---|---|
| `/product-media/memory-chat.webp` | 拾忆 AI 对话截图 | 真实 `alt="拾忆 AI 对话界面"` | 宽高比 2144×1546，`object-fit:cover` |
| 字体 `Geist Mono` | eyebrow | — | 大写等宽 |

## 9. AgentDock 内容映射（本组件承载「状态历史」）

Vokie 的「拾忆 = 和语音历史对话」对应 AgentDock 的**状态历史 / 会话时间线**能力：把过去的 agent 运行、审批、用量沉淀为可回看的记录。映射建议：

- **eyebrow**：`07 / 状态历史`（或 `Timeline`）。
- **h2**：例如「回看每个 agent 做过什么」。
- **描述**：「AgentDock 在本地保留会话状态与审批记录：回看 Claude Code / Codex / Cursor 何时运行、何时等待、何时用量见顶——无需再翻各自终端。」（须与真实实现一致，不夸大为「可对话式 AI 检索」，除非产品确有该能力。）
- **截图槽**：替换为 AgentDock 的历史/时间线界面截图；沿用 `has-product-media` 的 `#050607` 深底 + `object-fit:cover`，保持「产品即视觉语言」原则（`PRODUCT.md` 设计原则 1、3）。
- **边界**：状态历史数据保存在设备本地（呼应 PrivacySection）；不要把它写成云端可搜索的聊天，除非已实现。

> 复用清单：`.memory-layout`（不等宽两列 + 垂直居中）、`.media-slot.has-product-media`（深底产品截图槽）、`[data-reveal]`。极简、可直接搬用，替换文案与截图即可。这是全站最容易迁移的一节。
