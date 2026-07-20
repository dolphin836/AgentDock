<!-- [skill: clone-website · 组件取证规格] Vokie Integrations Grid → AgentDock 组件规格（仅规格，不改生产代码） -->
# Context Integrations Grid 规格

> 来源：https://vokie.com/ `#agent.context-chapter-reverse`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标与 DOM

反向 integrations grid：左侧四张 Skills 卡，右侧 sticky 文案与只读边界说明。

```html
<div id="agent" class="context-chapter context-chapter-reverse section-inner">
  <div class="context-copy">
    <p class="eyebrow">06 / Vokie Skills</p>
    <h2>不用再把那场会<br>讲一遍</h2>
    <p>由你主动安装 Vokie Skill 后，Agent 可以在任务中搜索 Vokie 的录音、转写和总结，也可以转写本地音视频。</p>
    <span class="boundary-note">当前 Skills 以只读查询为主。</span>
  </div>
  <div class="context-stack">
    <article class="context-card" data-reveal>
      <span>01</span><h3>会议已经在 Vokie</h3><p>转写与总结成为可查询的上下文。</p>
      <img class="agent-skill-icon" src="/assets/skill-meeting-qwvE1G3p.png"
        alt="" aria-hidden="true" loading="lazy" decoding="async">
    </article>
    <article class="context-card" data-reveal>02 Agent 按任务检索…skill-search-aPWyBk_4.png</article>
    <article class="context-card" data-reveal>03 继续完成工作…skill-continue-D6B55-EQ.png</article>
    <article class="context-card" data-reveal>04 查询 Vokie 历史…skill-history-D95fD-u6.png</article>
  </div>
</div>
```

## Exact styles

```css
.context-chapter-reverse{grid-template-columns:1.18fr .82fr}
.context-chapter-reverse .context-copy{grid-area:1/2}
.context-chapter-reverse .context-stack{grid-area:1/1}
.context-copy{position:sticky;top:128px;align-self:start;padding-bottom:80px}
.context-copy .eyebrow{color:#f6f8f87a;margin-bottom:30px}
.context-copy h2{margin-bottom:32px;font-size:58px;font-weight:560;line-height:1}
.context-copy>p{max-width:520px;color:#f6f8f8a3;font-size:18px;line-height:1.72}
.boundary-note{display:inline-block;margin-top:24px;padding-top:14px;
  border-top:1px solid #dadada33;color:#f6f8f87a;
  font:520 12px/1.3 "Geist Mono",monospace;text-transform:uppercase}
.context-stack{display:flex;flex-direction:column;gap:22px;padding-bottom:80px}
.context-card{position:sticky;top:116px;min-height:300px;padding:34px;
  border:1px solid #dadada33;border-radius:20px;background:#1b1b1b}
.context-card:nth-child(2){top:138px;background:#1b2028}
.context-card:nth-child(3){top:160px;background:#1b1b1b}
.context-card:nth-child(4){top:182px;background:#1b2028}
.context-card>span{color:#f6f8f86b;font:520 12px/1.3 "Geist Mono",monospace}
.context-card h3{max-width:62%;margin-top:104px;font-size:36px;font-weight:550;line-height:1.1}
.context-card p{max-width:62%;margin-top:18px;color:#f6f8f89e;font-size:16px;line-height:1.65}
.agent-skill-icon{position:absolute;top:8px;right:8px;width:100px;height:100px;
  opacity:.15;object-fit:contain;pointer-events:none}
```

≥901 全局 `body main h2/h3{font-size:30px!important}`，1440 实测标题均 30px。

## States

- **Model:** scroll-driven CSS sticky stack + IntersectionObserver reveal；无 click/hover。
- copy 固定 `top:128px`；卡按 `116/138/160/182px` 依次 sticky 覆盖。
- reveal：`opacity:0;translateY(32px)` → `.is-visible` `opacity:1;translateY(0)`，`.9s var(--ease-out)`。
- 图标 `opacity:.15`、`pointer-events:none`、`aria-hidden`；不参与交互或无障碍树。
- `.boundary-note` 是静态 span，不可聚焦、不可点击。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---|---|---|
| grid | `1.18fr .82fr`；卡左文右 | 单列；grid-area auto，文案回到卡上 | 单列 |
| copy/card | sticky | static / relative | static / relative |
| card | 300px；34px | 基础尺寸 | 240px；24px |
| h2 / h3 | 30 / 30px | 58 / 36px | 40 / 29px |
| icon | 100×100；top/right 8px | 同左 | 100×100；top/right 4px |
| boundary-note | 12px | 12px | 10px |

≤900 取消 sticky 并恢复 DOM 顺序；≤680 移动尺寸生效。

## Reduced motion

`transition/animation-duration:.01ms!important`；所有 `[data-reveal]` 直接 `opacity:1;transform:none`。桌面 sticky 仍保留，因为它是布局行为而非补间。

## Assets

`skill-meeting-*`、`skill-search-*`、`skill-continue-*`、`skill-history-*`：lazy/async 的装饰 PNG，全部 `alt="" aria-hidden="true"`。

## AgentDock 映射

- 改为真实 integrations：Claude hooks/status line、Codex notify、本地 session observation、Cursor 状态/用量；卡图替换为 agent wordmark 水印。
- 文案侧映射「点击返回 iTerm2、Terminal、VS Code」及支持的审批协助。
- `.boundary-note` 必须明确：**Claude Code 审批不自动化；协助审批仅 Codex 与 Cursor 可用。**
- 所有安装与权限描述需由当前 release 验证，不得声称全自动或写入 agent 历史。
