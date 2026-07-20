<!-- [skill: clone-website · 组件取证规格] Vokie ContextFocus → AgentDock 组件规格（仅规格，不改生产代码；所有数值来自 https://vokie.com/ 实测） -->
# ContextFocus 组件规格（Vokie → AgentDock）

> 取证来源：`https://vokie.com/` 的 `section#context-focus.context-focus.has-webgl`，2026-07-20，Browser MCP + `getComputedStyle` / `document.styleSheets` 实测。仅规格，不实现。

## 1. 目标 Next 组件路径

- 主组件：`src/components/sections/context-focus.tsx`（`"use client"`，全屏 WebGL 舞台 + 居中标题）
- 子件：`src/components/sections/context-focus-canvas.tsx`（three.js 粒子场，`ssr:false` 动态加载）
- 挂载点：`<main>` 内第三 section（`id="context-focus"`，紧随 Ethos），`data-header="light"`。

## 2. 参考截图

| 状态 | 文件 |
|---|---|
| 1440（粒子场 + 居中大写标题） | `./assets/contextfocus-1440.png` |
| 1440 reduced-motion（揭示直显） | `./assets/contextfocus-1440-reduced-motion.png` |
| 768 | `./assets/contextfocus-768.png` |
| 390 | `./assets/contextfocus-390.png` |

## 3. DOM 结构（实测）

```html
<section class="context-focus has-webgl" id="context-focus" data-header="light" aria-labelledby="context-focus-title">
  <div class="context-focus-scene" aria-hidden="true">
    <canvas class="context-focus-canvas" id="context-focus-canvas" data-engine="three.js r185"
            width="1440" height="900" style="width:1440px; height:900px;"></canvas>
  </div>
  <div class="context-focus-vignette" aria-hidden="true"></div>
  <div class="context-focus-copy">
    <div class="context-focus-heading-group">
      <p class="context-focus-eyebrow" data-focus-reveal data-i18n="contextFocus.eyebrow">不止于转写</p>
      <h2 class="context-focus-title" id="context-focus-title" data-focus-reveal data-i18n="contextFocus.title">
        <span class="context-focus-title-line">说过的话，<span class="context-focus-nowrap">不止成为文字。</span></span>
        <span class="context-focus-title-line">还是<span class="context-focus-nowrap">可调用的 Agent 上下文</span></span>
      </h2>
    </div>
    <p class="context-focus-description" data-focus-reveal data-i18n="contextFocus.description">Vokie 把语音输入、会议记录和本地音视频放进同一套上下文系统：当下生成可用结果，之后还能在拾忆中继续使用，或由 Agent 按需查询。</p>
  </div>
</section>
```
- 初始 `[data-focus-reveal]` 内联样式实测：`transform: translate(0px, 64px); opacity: 0`（GSAP 滚动揭示前的初值）。

## 4. 精确 getComputedStyle（1440×900）

### `section#context-focus.context-focus`
```
display: flex;  justify-content: center;  align-items: center;  position: relative;
width: 100%;  height: 100dvh (实测 900);  overflow: hidden;  isolation: isolate;
background: var(--paper)=rgb(218,218,218);  color: var(--carbon)=rgb(17,17,17);
```
### `.context-focus-scene`（画布容器）
```
position: absolute;  inset: 0;  z-index: 0;  overflow: hidden;  pointer-events: none;
mask-image: linear-gradient(rgba(0,0,0,0), #000 20%, #000 80%, rgba(0,0,0,0));   /* 上下淡出 */
```
### `.context-focus-canvas`
```
position: absolute;  inset: 0;  width: 100vw;  max-width: none;  height: 100%;
data-engine="three.js r185"（粒子场；DPR 下像素 = 2× CSS）
```
### `.context-focus-vignette`
```
position: absolute;  inset: 0;  z-index: 3;  pointer-events: none;
background: linear-gradient(to bottom, var(--paper) 0%, #dadada00 50%, var(--paper) 100%);   /* 顶/底纸色渐隐 */
(≤767px: display:none)
```
### `.context-focus-copy`
```
position: relative;  z-index: 2;  display: flex;  flex-direction: column;  align-items: center;
gap: 30px;  width: min(100% - 20px, 895px);  text-align: center;
(≤767px: width: calc(100% - 80px))
```
### `.context-focus-eyebrow`
```
font-family: "Geist Mono", monospace;  font-size: 14px;  font-weight: 520;  line-height: 1.2;
text-transform: uppercase;  color: rgb(17,17,17);   (≤767px: 12px)
```
### `.context-focus-title`（h2）
```
font-size: 60px !important;  font-weight: 560;  line-height: 1.08;  text-transform: uppercase;
text-align: center;  text-wrap: balance;  color: rgb(17,17,17);   (rect w=895,h=130)
胜出于 body main h2(30px!important)：.context-focus-title 类选择器特异性更高 → 60px 生效
(≤767px: font-size: 36px !important)
.context-focus-title-line { display:block; text-wrap:balance }
.context-focus-nowrap { white-space:nowrap }  (≤767: normal；仅首行首个 nowrap 保持 nowrap)
```
### `.context-focus-description`
```
font-size: 16px;  line-height: 1.2;  text-align: center;  width: min(100%,550px);  text-wrap: pretty;
color: rgb(17,17,17);   (≤767px: font-size:14px; line-height:1.15; max-width:305px)
```

## 5. 交互模型与全部状态

- **入场（scroll）**：`[data-focus-reveal]`（eyebrow / title / description）初值 `transform: translate(0,64px); opacity:0` → 进入视口时由 GSAP ScrollTrigger 上移归位、渐显。
- **WebGL 舞台**：`#context-focus-canvas`（three.js r185）常驻粒子场，随滚动/时间演化；`.context-focus-scene` 用 `mask-image` 上下淡出、`.context-focus-vignette` 用纸色渐变把画布融入 `--paper` 背景，令居中文本清晰。
- **无 hover/click/focus 交互**：画布 `aria-hidden` + `pointer-events:none`；section 以 `aria-labelledby` 指向标题，纯展示型。
- **scroll 高度**：`height:100dvh` 独占一屏；`data-header="light"` 使 Header 切浅色主题。

## 6. 响应式（断点实测）

| 视口 | 行为 |
|---|---|
| **1440** | 100dvh；标题 60px 大写两行；vignette 生效；描述 16px/550px。见 `./assets/contextfocus-1440.png`。 |
| **768**（≤767px）| `vignette{display:none}`；copy 宽 `calc(100% - 80px)`；eyebrow 12px；标题 36px；描述 14px/305px；`nowrap` 大多解除（仅首行首段保持不换行）。见 `./assets/contextfocus-768.png`。 |
| **390** | 同 ≤767 规则；标题 36px 多行；粒子场铺满。见 `./assets/contextfocus-390.png`。 |

关键断点：**767px**（vignette 关闭、标题 60→36px、nowrap 放开）。

## 7. reduced-motion

`@media (prefers-reduced-motion: reduce)`：`[data-reveal]`/揭示直显（`opacity:1; transform:none`），全局过渡/动画 `.01ms`；`data-focus-reveal` 由 GSAP 控制，reduced-motion 下应直接呈终态（见 `./assets/contextfocus-1440-reduced-motion.png`）。three.js 粒子场无原生 reduced-motion 关停规则 —— 属实现约束（见证据缺口）。

## 8. 资源层

- WebGL：`assets/three-*.js`（three.js r185）+ 专用 `assets/context-focus-*.js` 驱动 `#context-focus-canvas`。
- 融合：CSS `mask-image`（scene 上下淡出）+ `.context-focus-vignette` 线性渐变（纸色包边）。
- 字体：MiSans（标题/描述）、Geist Mono（eyebrow）。
- 动效：GSAP ScrollTrigger（`data-focus-reveal`）。

## 9. 原站文本（仅取证）

eyebrow「不止于转写」；标题「说过的话，不止成为文字。还是可调用的 Agent 上下文」；描述「Vokie 把语音输入、会议记录和本地音视频放进同一套上下文系统：当下生成可用结果，之后还能在拾忆中继续使用，或由 Agent 按需查询。」

## 10. AgentDock 内容替换映射（依设计文档 §3 实时状态 / 集成）

| 槽位 | Vokie | AgentDock |
|---|---|---|
| eyebrow | 不止于转写 | 不止于通知 |
| 标题（两行大写） | 说过的话，不止成为文字。/ 还是可调用的 Agent 上下文 | 看得见的状态，/ 也是可操作的工作面板 |
| 描述 | …同一套上下文系统… | AgentDock 把 Claude Code、Codex、Cursor 的运行、审批与用量放进 macOS 刘海：随时查看，一键返回对应工作区。 |
| 画布 | 语音粒子场 | 保持粒子场（抽象上下文意象）或替换为多 Agent 状态节点可视化 |

保留：全屏 100dvh 舞台、`--paper` 纸底 + `--carbon` 文本、居中大写超宽标题（`text-wrap:balance` + `nowrap` 控制断行）、WebGL 粒子场 + `mask-image`/vignette 融合、`data-focus-reveal` 上移渐显、≤767 关 vignette 与标题降级。标题走双语 `data-i18n`。

## 11. 证据缺口

- **粒子场 reduced-motion 降级**：原站未见针对 `#context-focus-canvas` 的 reduced-motion CSS；three.js 是否自停未测。实现须显式在 `prefers-reduced-motion:reduce` 停止/静帧。
- `data-focus-reveal` 的 GSAP 时间线（stagger、scrub 与 pin 与否）为 JS 行为，仅取到初值 `translate(0,64px)/opacity:0` 与终态；未逐帧建模。
- 画布粒子的具体几何/密度/交互（是否随滚动/指针变化）未做 WebGL 内部取证，属 `context-focus-*.js` 实现细节。
