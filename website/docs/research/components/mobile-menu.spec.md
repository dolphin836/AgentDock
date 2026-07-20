<!-- [skill: clone-website · 组件取证规格] Vokie MobileMenu → AgentDock 组件规格（仅规格，不改生产代码；所有数值来自 https://vokie.com/ 实测） -->
# MobileMenu 组件规格（Vokie → AgentDock）

> 取证来源：`https://vokie.com/`，2026-07-20，Browser MCP + `getComputedStyle` / `document.styleSheets` 实测。仅规格，不实现。

## 1. 目标 Next 组件路径

- 主组件：`src/components/layout/mobile-menu.tsx`（`"use client"`）
- 由 `src/components/layout/header.tsx` 的 `#menu-toggle` 控制开合；两者共享 `open` 状态。

## 2. 参考截图

| 状态 | 文件 |
|---|---|
| 390 打开（2 列 + 全宽下载） | `./assets/mobilemenu-390-open.png` |
| 768 打开 | `./assets/mobilemenu-768-open.png` |
| 390 触发器（汉堡→X 在 header 截图内） | `./assets/header-390-default.png` |
| 全页参考 | `../design-references/vokie/vokie-mobile-menu-390.png` |

## 3. DOM 结构（实测 outerHTML）

```html
<div class="mobile-menu" id="mobile-menu" aria-hidden="true" inert="">
  <nav aria-label="移动端导航" data-i18n-aria="a11y.mobileNav">
    <a href="#voice"   data-i18n="nav.product">听写</a>
    <a href="#meeting" data-i18n="nav.meeting">记录</a>
    <a href="#agent"   data-i18n="nav.agent">Agent</a>
    <a href="#privacy" data-i18n="nav.privacy">隐私</a>
    <a href="/download.html" data-i18n="nav.download">下载 Vokie</a>
  </nav>
</div>
```
- 关闭态带 `aria-hidden="true"` 与 `inert`（不可聚焦）；打开时 JS 移除 `inert`、置 `aria-hidden="false"`、加 `.is-open`，并把 `#menu-toggle` 的 `aria-expanded` 置 `true`。

## 4. 精确 getComputedStyle / authored 规则

### `.mobile-menu`
```
position: fixed;  inset: 0;  z-index: 90;
display: none  →  (≤900px) display: grid;
padding: 112px var(--page-gutter) 32px   (= 112px 40px 32px);  (≤680px) padding-top: 92px
color: var(--paper)=#dadada;
background: rgba(11,13,16,0.96);  backdrop-filter: blur(12px);
opacity: 0;  pointer-events: none;  transition: opacity .32s;
```
### `.mobile-menu.is-open`
```
opacity: 1;  pointer-events: auto;
```
### `.mobile-menu nav`
```
display: grid;  grid-template-columns: 1fr 1fr;  border-top: 1px solid rgba(255,255,255,0.16);
```
### `.mobile-menu a`（每一项）
```
display: flex;  align-items: flex-end;  min-height: 110px;  (≤680px) min-height: 92px
padding: 16px 0;  font-size: 28px;  (≤680px) font-size: 23px;  font-weight: 540;
border-bottom: 1px solid rgba(255,255,255,0.16);
clip-path: inset(100% 0 0);           /* 初始：内容自下向上被裁切 */
transition: clip-path .42s var(--ease-structural);
a:nth-child(2n+1) { border-right: 1px solid rgba(255,255,255,0.16); padding-right: 16px; }  /* 左列 */
a:nth-child(2n)   { padding-left: 16px; }                                                    /* 右列 */
a:last-child      { grid-column: 1 / -1; color: rgb(143,176,255)=#8fb0ff; border-right: 0; padding-left: 0; }  /* 下载：整行、蓝色 */
```
### `.mobile-menu.is-open a`
```
clip-path: inset(0);   /* 打开时逐项向上揭示（wipe-up reveal） */
```

## 5. 交互模型与全部状态

- **click（打开）**：点击 `#menu-toggle` → `.mobile-menu` 加 `.is-open`（`opacity 0→1`, `.32s`），各链接 `clip-path` 从 `inset(100% 0 0)` → `inset(0)`，`.42s var(--ease-structural)` 的自下而上揭示；`#menu-toggle` 四点旋转成 X（见 header.spec §6.5）。
- **click（关闭）**：再次点击 `#menu-toggle`（或点击任意链接跳转锚点）→ 移除 `.is-open`，恢复 `inert`/`aria-hidden`。
- **hover**：链接无独立 hover 样式变化（触屏优先）；下载项恒为 `#8fb0ff`。
- **focus**：关闭态因 `inert` 不可聚焦；打开态链接可 Tab 聚焦（依赖浏览器默认 focus-visible + 全局 `:focus-visible` 由页面统一定义）。
- **scroll**：菜单为 `position:fixed; inset:0` 全屏覆盖，覆盖期间背景不可交互（`pointer-events` 切换）。

## 6. 响应式（断点实测）

| 视口 | 行为 |
|---|---|
| **1440** | `display:none`，永不出现（桌面用 `.desktop-nav`）。 |
| **768**（≤900px 触发）| `display:grid`；2 列网格；项 `min-height:110px`，`font-size:28px`；`padding-top:112px`。见 `./assets/mobilemenu-768-open.png`。 |
| **390**（≤680px）| 2 列；项 `min-height:92px`，`font-size:23px`；`padding-top:92px`。下载项整行、`#8fb0ff`。见 `./assets/mobilemenu-390-open.png`。 |

出现条件：**≤900px**（与 `.menu-toggle` 同断点）。

## 7. reduced-motion

`@media (prefers-reduced-motion: reduce)` 下全局 `transition-duration:.01ms!important`，`opacity` 与 `clip-path` 揭示近乎瞬时完成；开合仍可用，仅无动画。

## 8. 资源层

- 无独立图片资源；仅文本链接 + 分隔线（`rgba(255,255,255,.16)`）。
- 字体同全站（MiSans / MiSans-Semibold / Geist Mono）。
- 背景毛玻璃依赖 `backdrop-filter: blur(12px)`（需注意 Safari `-webkit-backdrop-filter` 前缀，实测 computed 未含前缀，实现时补齐）。

## 9. 原站文本（仅取证）

「听写 / 记录 / Agent / 隐私 / 下载 Vokie」。

## 10. AgentDock 内容替换映射

| 槽位 | Vokie | AgentDock | 锚点 |
|---|---|---|---|
| 项 1 | 听写 | 状态 | `#status` |
| 项 2 | 记录 | 审批 | `#approval` |
| 项 3 | Agent | 集成 | `#integrations` |
| 项 4 | 隐私 | 隐私 | `#privacy` |
| 下载（整行、强调蓝） | 下载 Vokie → `/download.html` | 下载 AgentDock → `https://api.agentdockstatus.app/v1/download/AgentDock-0.2.4.dmg` | — |

保留：全屏毛玻璃暗底、2 列网格、`min-height` 大热区（≥92px，满足 44px 触达）、逐项 `clip-path` 揭示、下载整行强调色（`#8fb0ff` 或替换为 AgentDock `--coral`）。菜单项须与 `Header`/`MobileMenu` 双语 `data-i18n` 键一致。

## 11. 证据缺口

- 逐项揭示是否带 stagger 延迟：CSS 未见 `transition-delay` 分级，实测为同一 `.42s` 过渡；若原站有 JS 逐项延迟则未在样式层捕获（标注为可能的 JS 行为，实现时可选加 60–80ms stagger）。
- 关闭动画是否与打开对称：仅确认 `.is-open` 移除后回到 `clip-path: inset(100% 0 0)`；关闭过渡时长未单独测定（默认沿用 `.42s`）。
