<!-- [skill: clone-website · 组件取证规格] Vokie IntroCurtain → AgentDock 组件规格（仅规格，不改生产代码；所有数值来自 https://vokie.com/ 实测） -->
# IntroCurtain 组件规格（Vokie → AgentDock）

> 取证来源：`https://vokie.com/`，2026-07-20，Browser MCP（CPU 6× 节流捕获运行帧）+ 同源 HTML/`document.styleSheets` 实测。仅规格，不实现。

## 1. 目标 Next 组件路径

- 主组件：`src/components/intro/intro-curtain.tsx`（`"use client"`，仅首屏载入播放一次）
- 挂载点：`src/app/layout.tsx` 内 `<body>` 首个子节点（在 Header 之上，`z-index:180` 覆盖全部）。
- 建议配合根节点类名管理：进入完成后为 `<html>` 添加 `motion-ready`（原站行为），驱动后续 `[data-reveal]` 揭示。

## 2. 参考截图

| 状态 | 文件 |
|---|---|
| 运行帧（`.is-running`，进度计数） | `./assets/introcurtain-1440-running.png` |
| 运行帧 2 | `./assets/introcurtain-1440-frame2.png` |

运行帧实测：纯 `#111` 底、居中「Vokie」符号+字标，右下角进度数字（截图捕获到 `41`，计数 `0→100`）。

## 3. DOM 结构（同源 HTML 实测，JS 播放后从 DOM 移除）

```html
<div class="intro-curtain" id="intro-curtain" aria-hidden="true">
  <div class="intro-mark">
    <img src="/vokie-symbol.svg" alt="" width="48" height="48">
    <span>Vokie</span>
  </div>
  <span class="intro-progress" id="intro-progress">0</span>
</div>
```
- 位于 `<body>` 顶部、`<header>` 之前。播放结束后由 JS 移除（稳定 DOM 中查询不到，故经 CPU 节流与同源 `fetch('/')` 取得原始标记）。

## 4. 精确样式（authored 规则实测）

### `.intro-curtain`
```
position: fixed;  inset: 0;  z-index: 180;
display: flex;  justify-content: center;  align-items: center;
background: var(--carbon)=#111;  color: var(--paper)=#dadada;
visibility: hidden;  opacity: 0;  pointer-events: none;
clip-path: inset(0);
transition: clip-path .9s var(--ease-structural), transform .9s var(--ease-structural);
```
### `.intro-curtain.is-running`（播放中）
```
visibility: visible;  opacity: 1;
```
### `.intro-curtain.is-complete`（收起离场）
```
clip-path: inset(0 0 100%);      /* 自下向上收起，露出下方 Hero */
transform: translateY(-24px);
```
### `.intro-mark`（居中品牌）
```
display: flex;  align-items: center;  gap: 14px;  font-size: 30px;  font-weight: 620;
(≤680px) font-size: 24px
img { width: 48px; height: 48px; filter: brightness(0) invert(); }   /* 白色符号 */
```
### `.intro-progress`（右下角计数）
```
position: absolute;  right: var(--page-gutter)=40px;  bottom: var(--page-gutter)=40px;
font-family: "Geist Mono", monospace;  font-size: 13px;
文本: 0 → 100（JS 递增）
```
- 令牌：`--ease-structural: cubic-bezier(.62,.16,.13,1.01)`。

## 5. 交互模型与全部状态（时序）

1. **初始**（首帧）：`.intro-curtain` 存在，`visibility:hidden; opacity:0`，位于 `z-index:180` 顶层。
2. **运行 `.is-running`**：`visible; opacity:1`，覆盖全屏；`#intro-progress` 从 `0` 计数到 `100`（见运行帧截图）。
3. **完成 `.is-complete`**：`clip-path: inset(0 0 100%)` 自下而上收起 + `transform: translateY(-24px)`，`.9s var(--ease-structural)`，露出 Hero；随后 `<html>` 获得 `motion-ready`，启动全站 `[data-reveal]` 揭示。
4. **结束**：元素从 DOM 移除，`z-index` 让位。

- 无 hover/click/focus 交互（纯载入动画，`pointer-events:none`，不拦截、不可聚焦，`aria-hidden="true"`）。
- **scroll**：播放期间锁定于视口顶部（`fixed inset:0`）；不响应滚动。

## 6. 响应式（断点实测）

| 视口 | 行为 |
|---|---|
| **1440** | 显示；品牌 30px；进度 Geist Mono 13px。 |
| **768** | 显示（>680px）；同 1440，品牌 30px。 |
| **390**（≤680px）| **`.intro-curtain { display: none }`** — 移动端不播放开幕帘。品牌尺寸规则 24px 仅在 681–? 生效，但 ≤680 整体隐藏。 |

关键：**≤680px 关闭 IntroCurtain**（移动端直接进入 Hero，避免遮挡与性能负担）。

## 7. reduced-motion

`@media (prefers-reduced-motion: reduce)` 下 **`.intro-curtain { display: none }`** —— 减弱动态偏好时完全跳过开幕，直接呈现 Hero。实现须遵守：`prefers-reduced-motion:reduce` 或 `max-width:680px` 任一命中即不渲染帘幕，且不得阻塞首屏内容/可访问性。

## 8. 资源层

- 符号：`/vokie-symbol.svg`（48×48，`filter: brightness(0) invert()` 反白）。
- 字体：Geist Mono（进度计数）+ MiSans/MiSans-Semibold（字标 620）。
- 逻辑脚本：`assets/main-*.js`（计数器 + 类切换）；离场缓动 `--ease-structural`。

## 9. 原站文本（仅取证）

品牌字标「Vokie」；进度数字「0…100」。

## 10. AgentDock 内容替换映射

| 槽位 | Vokie | AgentDock |
|---|---|---|
| 符号 | `/vokie-symbol.svg` | AgentDock 图标（48×48，可反白，置于 `public/`） |
| 字标 | Vokie | AgentDock |
| 进度 | 0→100 | 0→100（保留 Geist Mono 命令行观感；或替换为「LOADING」等价键） |
| 底色 | `#111` (`--carbon`) | `--carbon` / 近黑 `#0b0d10`（设计文档主背景），二选一 |

保留：`z-index:180` 全屏、`clip-path` 自下而上收起 + `translateY(-24px)` 离场、`.9s var(--ease-structural)` 缓动、完成后为根节点加 `motion-ready` 启动揭示、**≤680px 与 reduced-motion 关闭**。字标须走双语 `data-i18n`。

## 11. 证据缺口

- **进度计数节奏**：仅确认 `0→100` 与运行帧数字，未逐帧测定递增函数/总时长（`.is-running` 持续时间由 JS 控制，样式层不可得）。实现时以「约 0.8–1.2s 线性/缓入计数后 `.is-complete` 收起」为基准，再对齐视觉。
- **`is-running`/`is-complete` 触发时机**：依赖 `main-*.js` 内部逻辑（字体/首资源就绪后启动），未做 JS 反编译；标注为 JS 行为。
- 运行帧截图为 CPU 6× 节流下捕获，进度值（41）为该帧瞬时值，非固定设计值。
