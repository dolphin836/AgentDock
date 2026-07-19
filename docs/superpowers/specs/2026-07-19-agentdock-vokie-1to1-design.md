<!-- [skill: go-team-standards · 技术方案] AgentDock 官网 Vokie 机制 1:1 重做 -->
# AgentDock 官网 Vokie 机制 1:1 重做设计

日期：2026-07-19
状态：用户已确认

## 1. 目标

按照 Vokie 当前官网的页面结构、空间节奏与交互机制 1:1 重做 AgentDock 官网，只替换品牌、文案、产品界面和粒子造型。不得复制 Vokie 的 Logo、图片、文案、源代码或专属图形。

“1:1”指以下机制保持一致：

- 固定导航从满宽细线栏收缩为悬浮胶囊，随滚动方向隐藏或出现。
- 导航前景随深浅章节切换，桌面导航指示线跟随 hover 和 focus。
- 移动端使用四格菜单按钮和全屏裁切菜单。
- 首屏严格控制为一个视口，动态粒子背景从散乱态收束为 AgentDock 刘海轮廓。
- 深浅章节使用圆角切片和 `clip-path` 滚动揭示。
- 核心产品旅程在桌面端固定并横向推进，移动端退化为纵向内容。
- 背景使用粒子、点阵、竖线、遮罩和 vignette 建立层次。
- 开场遮幕、标题裁切入场、滚动绑定动画与 reduced-motion 降级保持同等级别。

## 2. 保留与推翻

### 2.1 保留

- AgentDock 的中英文文案系统和浏览器语言选择。
- 现有下载地址、版本号与 `scripts/package.sh` 兼容性。
- 刘海展开、审批演示、状态轮播与真实产品事实边界。
- 键盘、ARIA、无 JavaScript 内容可用和 reduced-motion 原则。
- 现有 favicon、AppIcon、macOS 壁纸与 Dock 资产。

### 2.2 推翻

- 当前 sticky 黑色工具栏。
- 当前 Hero 的“标题后纵向堆叠 560px 设备舞台”结构。
- 仅靠 `.dark-section` / `.light-section` 硬切背景。
- 所有章节重复“标题 + 横线列表”的模板。
- 全页统一 18px 淡入作为主要动效。
- 仅使用沙丘壁纸作为核心视觉的策略。

## 3. 页面结构

1. **Intro curtain**：AgentDock 标识、0 到 100 进度、向上裁切离场。
2. **Hero**：粒子刘海、标题、下载、产品说明，完整占据一屏。
3. **Focus reveal**：浅色章节从右向左揭开，说明“不用检查每个窗口”。
4. **Capability panels**：状态、审批、用量、返回工作区四组伸缩面板。
5. **Agent context**：第二套浅色粒子场，突出三类 Agent 汇入同一入口。
6. **Workflow journey**：桌面横向固定旅程，依次展示运行、等待审批、查看用量、返回现场。
7. **Integrations**：竖线背景生长，说明 Claude Code、Codex、Cursor 的本地集成。
8. **Privacy**：向左出血的浅色大卡片，说明数据和权限边界。
9. **Final CTA**：向右出血的珊瑚色大卡片，完成下载行动。

## 4. 导航

### 4.1 桌面

- 初始高度 80px，固定在顶部，三列 Grid：品牌、章节导航、语言与下载。
- 滚动超过视口高度 22% 后变为最大宽度 920px、高度 58px、顶部 11px 的悬浮胶囊。
- 胶囊使用 14px 背景模糊、1px 边框和 6px 圆角。
- 滚动超过一屏后，向下滚动超过 12px 时隐藏，向上滚动时显示。
- 每个章节通过 `data-header="dark|light"` 显式控制导航主题。
- hover/focus 导航项时，1px 指示线读取元素几何并移动到对应位置。

### 4.2 移动端

- 900px 以下隐藏桌面导航和头部下载按钮。
- 四个 5px 空心方块组成菜单按钮，展开后旋转为交叉形态。
- 全屏菜单使用深色半透明背景和 12px 模糊。
- 链接按顺序使用 `clip-path` 从底部揭示。
- 支持 Escape、焦点圈定、首项聚焦、`aria-expanded`、`aria-hidden` 和 `inert`。

## 5. 背景和粒子

### 5.1 Hero 粒子

- 使用 Three.js WebGLRenderer，透明背景、关闭抗锯齿、优先高性能。
- 桌面 2200 点，移动端或低性能设备 1200 点。
- 每个粒子包含散乱位置和结构化位置，通过 shader 的 `uProgress` 插值。
- 结构化形状为 AgentDock 刘海轮廓与两侧状态带，不复制 Vokie 形状。
- 首次进入时在 1.9 秒内从散点收束。
- 非触摸、非 reduced-motion 时支持轻微鼠标扰动和呼吸。
- 页面隐藏或 Canvas 不可见时暂停 RAF，像素比最高 1.5。

### 5.2 Context 粒子

- 第二套粒子场延迟加载，不阻塞首屏。
- 使用纵向 mask 和 vignette，把粒子限制在文字后方中部。
- 根据 `saveData`、设备内存、CPU 核数和 pointer 类型决定预热或延迟初始化。
- reduced-motion 下只渲染静态一帧。

### 5.3 其他背景

- 状态演示使用两层 radial-gradient 点阵。
- Integrations 使用五列低对比竖线，滚动时从 20% 生长到 100%。
- 不使用统一噪点覆盖全页。

## 6. 滚动与转场

- 使用 GSAP 和 ScrollTrigger，本地静态资源，不依赖运行时 CDN。
- Hero 标题从底部裁切进入，CTA 和说明错峰淡入。
- 第一浅色章节从 `clip-path: inset(0 100% 0 0)` 横向揭开。
- 核心旅程在桌面 `min-width: 901px` 且 `min-height: 700px` 时 pin，并按内容宽度横向移动。
- 移动端、矮屏或 reduced-motion 使用普通纵向布局。
- 常规内容 reveal 仅在 `.motion-ready` 后隐藏，确保 JS 失败不丢内容。
- 所有 scrub 动画绑定可见区间，不使用高频裸 scroll 写布局。

## 7. 原创内容

### 7.1 Hero

- 标题：`Every agent in view. / Your focus stays intact.`
- 中文：`所有 Agent，都在眼前。/ 你的专注，不被打断。`
- 说明：Claude Code、Codex 和 Cursor 的状态、审批与用量统一进入 macOS 刘海。

### 7.2 产品旅程

1. 运行：知道哪个 Agent 正在执行、思考或空闲。
2. 等待：审批需要你时，刘海主动提示。
3. 用量：三类 Agent 的额度和上下文集中查看。
4. 返回：点击会话，回到对应终端或编辑器。

### 7.3 集成与隐私

- Claude Code：hooks 与 status line。
- Codex：notify 与本地 session log。
- Cursor：hooks、transcript、状态和用量。
- 会话内容、路径和 token 明细不上传。
- 有限遥测使用安装级标识，不包含会话内容和文件路径。
- Automation 用于返回工作区，Accessibility 用于支持的辅助审批。

## 8. 响应式与降级

- 900px：桌面导航切换移动菜单，横向旅程退化纵向。
- 767px：伸缩面板变完整纵向卡片，第二粒子场降低密度。
- 680px：关闭 intro curtain，gutter 18px，Hero 保持一屏。
- reduced-motion：移除 curtain、scrub、pin、粒子持续动画、CTA sheen 和逐项揭示；所有内容静态可见。
- WebGL 初始化失败：保留 CSS 点阵与静态刘海产品界面。
- JavaScript 失败：英文内容、导航锚点和下载链接可用。

## 9. 技术结构

```text
site/
├── index.html
├── styles.css
├── main.js
├── motion.js
├── hero-particles.js
├── context-particles.js
└── vendor/
    ├── three.module.min.js
    ├── gsap.min.js
    ├── ScrollTrigger.min.js
    └── LICENSES.txt
```

## 10. 验收

- 与 Vokie 在 1440px 桌面端逐折对照导航形态、Hero 占屏、浅色揭示、横向旅程、背景层和最终 CTA。
- 在 390×844 验证移动菜单、纵向旅程、无横向溢出和触控目标。
- 验证中文和英文、reduced-motion、WebGL 失败、JavaScript 关闭。
- 验证所有下载链接与发布脚本版本替换。
- 运行静态官网契约、JavaScript 语法检查、Swift 测试和最终代码评审。
