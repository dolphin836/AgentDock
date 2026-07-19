<!-- [skill: go-team-standards · 技术方案] AgentDock 官网 Vokie 机制 1:1 实施计划 -->
# AgentDock Vokie 1:1 Homepage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 按 Vokie 当前线上版的导航、背景和滚动机制 1:1 重做 AgentDock 官网，并替换为 AgentDock 原创品牌内容。

**Architecture:** 保留纯静态发布，新增本地 vendored Three.js、GSAP 和 ScrollTrigger。页面拆分为语义内容、导航/交互控制、滚动编排和两套粒子场；重动效按设备能力和 reduced-motion 分级。

**Tech Stack:** HTML5、CSS、原生 JavaScript、Three.js、GSAP、ScrollTrigger、Python 静态契约检查、Chrome CDP。

## Global Constraints

- 不复制 Vokie 的 Logo、图片、文案、源代码或专属粒子形状。
- 视觉结构和交互机制按线上 Vokie 当前实现对齐。
- 所有第三方库必须本地托管并记录许可证，不使用运行时 CDN。
- 内容使用 AgentDock 原创文案和真实产品能力。
- 下载地址、版本号和 `scripts/package.sh` 替换保持兼容。
- JavaScript 或 WebGL 失败时，内容与下载仍可用。
- 完整支持中英文、键盘、ARIA 和 reduced-motion。

---

### Task 1: Vendor motion libraries and strengthen contracts

**Files:**
- Create: `site/vendor/three.module.min.js`
- Create: `site/vendor/gsap.min.js`
- Create: `site/vendor/ScrollTrigger.min.js`
- Create: `site/vendor/LICENSES.txt`
- Modify: `scripts/check_site.py`

- [ ] 使用包管理器获取最新稳定 Three.js 和 GSAP，将浏览器产物复制到 `site/vendor/`。
- [ ] 记录版本、许可证和上游地址。
- [ ] 先扩展静态契约，要求本地 vendor 文件、模块入口、页面 scene ID 和无 CDN 引用，观察 RED。
- [ ] 运行 `python3 scripts/check_site.py` 达到 GREEN。
- [ ] Commit：`build(site): vendor motion libraries`

### Task 2: Rebuild header, intro curtain, and mobile menu

**Files:**
- Modify: `site/index.html`
- Modify: `site/styles.css`
- Modify: `site/main.js`
- Modify: `scripts/check_site.py`

- [ ] 先添加 header DOM、主题状态、四格菜单、移动菜单 ARIA 和滚动形态契约，观察 RED。
- [ ] 实现 80px 满宽导航、22vh 后 920×58 悬浮态、滚动方向隐藏、章节深浅主题。
- [ ] 实现 hover/focus 几何指示线。
- [ ] 实现移动全屏菜单、clip-path 链接揭示、焦点圈定、Escape 和 inert。
- [ ] 实现 intro curtain 和资源超时兜底。
- [ ] reduced-motion 与 680px 以下移除 curtain。
- [ ] Commit：`feat(site): rebuild adaptive navigation`

### Task 3: Build the one-viewport particle hero

**Files:**
- Modify: `site/index.html`
- Modify: `site/styles.css`
- Create: `site/hero-particles.js`
- Modify: `site/motion.js`
- Modify: `scripts/check_site.py`

- [ ] 先添加 Hero 高度、Canvas、fallback 和 reduced-motion 契约，观察 RED。
- [ ] 将 Hero 改为严格的一屏三行 Grid。
- [ ] 用 Three.js shader 创建 scatter/structured 双位置粒子，结构化形状为 AgentDock 刘海。
- [ ] GSAP 驱动 1.9 秒收束、标题裁切和底部内容入场。
- [ ] 实现鼠标扰动、呼吸、可见性暂停、DPR 上限和低性能点数降级。
- [ ] WebGL 失败时保留静态点阵和产品界面。
- [ ] Commit：`feat(site): add particle notch hero`

### Task 4: Rebuild chapter choreography and product journey

**Files:**
- Modify: `site/index.html`
- Modify: `site/styles.css`
- Create: `site/motion.js`
- Create: `site/context-particles.js`
- Modify: `site/main.js`
- Modify: `scripts/check_site.py`

- [ ] 先添加 reveal-band、capability panels、context scene、journey track、background lines 和 out-bleed CTA 契约，观察 RED。
- [ ] 实现首个浅色章节从右向左裁切揭示。
- [ ] 实现四组伸缩 capability panels，移动端纵向退化。
- [ ] 实现延迟加载的第二粒子场、mask 和 vignette。
- [ ] 实现桌面横向 pinned journey 与进度线，移动端/矮屏/reduced-motion 纵向退化。
- [ ] 实现五列竖线滚动生长、向左出血隐私卡和向右出血最终 CTA。
- [ ] Commit：`feat(site): add scroll-driven product journey`

### Task 5: Replace all content and harden fallbacks

**Files:**
- Modify: `site/index.html`
- Modify: `site/main.js`
- Modify: `site/styles.css`
- Modify: `scripts/check_site.py`

- [ ] 写入设计文档定义的 AgentDock 原创中英文文案。
- [ ] 保持翻译键对称、浏览器语言选择和 localStorage 降级。
- [ ] 核对 Claude Code、Codex、Cursor、审批、遥测、权限和下载事实。
- [ ] 验证 JS 关闭、WebGL 失败、saveData、低内存和 reduced-motion。
- [ ] Commit：`feat(site): complete AgentDock narrative`

### Task 6: Visual comparison, critique, and release verification

**Files:**
- Modify: `design-qa.md`
- Modify as needed: `site/*`
- Modify as needed: `scripts/check_site.py`

- [ ] 在 1440×1000、1280×800、834×1194、390×844、360×800 截图。
- [ ] 与 Vokie 对照导航初始/收缩、Hero、一浅色揭示、横向旅程、背景和 CTA。
- [ ] 完成至少一次 critique-and-fix，任何缺陷先加回归契约再修复。
- [ ] 验证中英文、移动菜单、键盘、reduced-motion、JS 关闭、WebGL 失败、资源和控制台。
- [ ] 验证 `scripts/package.sh` 同款替换。
- [ ] 运行：

```bash
python3 scripts/check_site.py
node --check site/main.js
node --check site/motion.js
node --check site/hero-particles.js
node --check site/context-particles.js
swift test
git diff --check
```

- [ ] 更新 `design-qa.md`，只记录真实证据。
- [ ] Commit：`test(site): verify Vokie parity`
