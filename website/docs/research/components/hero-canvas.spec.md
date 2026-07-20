<!-- [skill: go-team-standards · clone-website · 组件取证规格] HeroCanvas：首屏 three.js 粒子背景与降级 -->
# HeroCanvas Specification

## Overview
- **唯一目标文件：** `src/components/sections/hero-canvas.tsx`
- **职责：** `#hero-canvas` WebGL 生命周期、尺寸、粒子背景、静态/无 WebGL/reduced-motion 降级。
- **Interaction model：** time-driven decorative canvas。
- **Builder 限制：** 只改此目标文件；不得实现 Hero 文案或 section 排版。

## Screenshots
- `./assets/hero-1440.png`
- `./assets/hero-768.png`
- `./assets/hero-390.png`

## DOM
```html
<canvas class="hero-canvas" id="hero-canvas" aria-hidden="true"></canvas>
```

## Exact computed evidence
- `.hero-canvas`: `display:block; position:absolute; inset:0; width:100%; height:100%; z-index:-1; pointer-events:none; background-color:rgba(0,0,0,0); opacity:1; transform:none; overflow:clip`。
- 1440 rect：`{x:0,w:1440,h:876}`。
- 390 证据：canvas CSS rect `390×826`；像素尺寸随 DPR/引擎设置。
- 父 section 背景 `rgb(17,17,17)`，粒子为灰白点阵，内容居中叠在其上。

## Behavior
- three.js 粒子云常驻缓慢运动；纯装饰，`pointer-events:none`、`aria-hidden`。
- 由原站 `assets/three-*.js` 初始化；脚本栈还包含 `assets/main-*.js`。
- resize 时 canvas 覆盖 `100%×100%`；renderer 尺寸须同步 viewport/DPR，并限制 DPR 避免移动性能问题。
- Canvas 位于 section stacking context 的 `z-index:-1`；HeroContent 为 z-index 3/4。

## Responsive evidence
- **1440：** 1440×876 CSS 区域，粒子云横向展开。
- **768：** 覆盖完整 Hero；粒子云仍在标题后。
- **390：** 覆盖 390×约826，粒子云缩成标题后的紧凑声波形；见 `hero-390.png`。
- section 高度断点由 `hero.spec.md` wrapper 负责，canvas 始终 `inset:0`。

## reduced-motion and fallbacks
- 原站 CSS **没有**针对 `.hero-canvas` 的 reduced-motion 规则。
- AgentDock 实现硬约束：`prefers-reduced-motion:reduce` 时停止 RAF 并显示静帧或隐藏；不可继续常驻动画。
- WebGL/three 动态 import 失败时保留 `#111` Hero 背景和可读内容，不抛出阻塞错误。
- client-only；建议 dynamic import / `ssr:false`，卸载时 cancel RAF、dispose geometry/material/renderer。

## Assets
- three.js r185（原站网络资源 `assets/three-*.js`）；无 `<img>` 层。
- 粒子几何、密度与 shader 未做脚本反编译。

## AgentDock mapping
- 可保留抽象粒子云，或转译为多 Agent 状态节点；不得复制 Vokie 专属语音波形资产。
- 设计原则优先真实产品：若以 macOS 刘海 product stage 替代，此组件仍只负责背景/画布层。

## Evidence gaps
- 粒子几何、密度、速度、是否响应指针/滚动未从 WebGL 内部提取。
- 原站 reduced-motion 是否在 JS 内自停未测；因此明确列为 AgentDock 必须实现的降级。
