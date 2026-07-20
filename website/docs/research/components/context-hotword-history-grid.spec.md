<!-- [skill: clone-website · 组件取证规格] Vokie Hotword/History Grid → AgentDock 组件规格（仅规格，不改生产代码） -->
# Context Hotword / History Grid 规格

> 来源：https://vokie.com/ `#personalization.context-chapter`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标与 DOM

热词/history grid：左侧 sticky 说明，右侧四张 sticky 卡，描述「修正一次 → 热词保存 → 下次识别」。

```html
<div id="personalization" class="context-chapter section-inner">
  <div class="context-copy">
    <p class="eyebrow">05 / 越用越熟悉</p>
    <h2>改正一次，<br>下次记住</h2>
    <p>手动修改识别结果后，Vokie 会学习人名、术语和专有词，并纳入热词。</p>
  </div>
  <div class="context-stack">
    <article class="context-card" data-reveal>
      <span>01</span><h3>你修正一次</h3><p>“沃奇” → “Vokie”</p>
      <img class="context-card-image" src="/assets/hotword-correct-white-BzI4hyGe.png"
        alt="Vokie 将错误词沃奇修正为 Vokie" loading="lazy" decoding="async">
    </article>
    <article class="context-card" data-reveal>02 进入热词…hotword-save-white-CepovRW5.png</article>
    <article class="context-card" data-reveal>03 下次认得…hotword-remember-white-rjW7kSP2.png</article>
    <article class="context-card hotword-summary-card" data-reveal>
      04 改正一次，下次记住…hotword-summary-white-D48kFp2A.png
    </article>
  </div>
</div>
```

卡片固定层级：序号 → h3 → p → img。四张图有语义 alt；第 4 张无 `data-i18n`，图片更宽。

## Exact styles

```css
.context-copy{position:sticky;top:128px;align-self:start;padding-bottom:80px}
.context-copy .eyebrow{color:#f6f8f87a;margin-bottom:30px}
.context-copy h2{margin-bottom:32px;font-size:58px;font-weight:560;line-height:1}
.context-copy>p{max-width:520px;color:#f6f8f8a3;font-size:18px;line-height:1.72}
.context-stack{display:flex;flex-direction:column;gap:22px;padding-bottom:80px}
.context-card{position:sticky;top:116px;min-height:300px;padding:34px;
  border:1px solid #dadada33;border-radius:20px;background:#1b1b1b}
.context-card:nth-child(2){top:138px;background:#1b2028}
.context-card:nth-child(3){top:160px;background:#1b1b1b}
.context-card:nth-child(4){top:182px;background:#1b2028}
.context-card>span{color:#f6f8f86b;font:520 12px/1.3 "Geist Mono",monospace}
.context-card h3{max-width:62%;margin-top:104px;font-size:36px;font-weight:550;line-height:1.1}
.context-card p{max-width:62%;margin-top:18px;color:#f6f8f89e;font-size:16px;line-height:1.65}
.context-card-image{position:absolute;top:36px;right:28px;bottom:36px;width:30%;
  height:calc(100% - 72px);object-fit:contain;object-position:center}
.context-card:nth-child(2) .context-card-image{width:33%}
.hotword-summary-card .context-card-image{width:36%;right:18px}
```

≥901 全局 `body main h2/h3{font-size:30px!important}`：1440 实测 copy h2 和卡 h3 为 30px；基础 58/36px 在 768 生效。

## States

- **Model:** CSS sticky scroll stack + IntersectionObserver reveal；无 click/hover。
- copy：`sticky top:128px`；卡片：`sticky top:116/138/160/182px`，后卡逐张覆盖前卡。
- reveal：`opacity:0;translateY(32px)` → `.is-visible` 的 `opacity:1;translateY(0)`，`.9s cubic-bezier(.22,1,.36,1)`。
- 卡片、图片均非交互；无 hover 样式。焦点沿全局 `2px solid --vokie-blue; offset 4px`。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---|---|---|
| grid | wrapper `.82fr 1.18fr` | 单列 | 单列 |
| copy | sticky 128px | static；padding-bottom 0 | static |
| card | sticky 116/138/160/182；300px；34px | relative；top auto | relative；240px；24px |
| image | absolute；30/33/36% | absolute | static；`min(100%,260px)`；`20px auto 0` |
| copy h2 | 30px | 58px | 40px |
| eyebrow | 18px（被 `.context-copy>p` 选择器覆盖） | 18px | 16px |

≤900 取消 copy/card sticky。≤680 卡图进入常规流；第 2 张上限 280px，第 4 张 300px。

## Reduced motion

全局把 transition/animation 压至 `.01ms`，`.motion-ready [data-reveal]{opacity:1;transform:none}`。纯 CSS sticky 仍存在于桌面；需要更保守时可在 reduce 下改为 `position:relative`。

## Assets

- `hotword-correct-white-*` / `hotword-save-white-*` / `hotword-remember-white-*` / `hotword-summary-white-*`：均 lazy + async，`object-fit:contain`。
- `Geist Mono`：序号与 eyebrow。

## AgentDock 映射

- 改为 AgentDock 状态/history 接入链：01 接入 Claude hooks/status line、Codex notify、Cursor 状态；02 会话进入 Dock；03 再次运行自动归位；04 一次配置后的统一状态历史。
- 图片换为真实 AgentDock 状态/历史截图；保留语义 alt，不复用 Vokie 资产。
- 不得声称未经验证的全自动安装、云端历史或跨设备同步。
