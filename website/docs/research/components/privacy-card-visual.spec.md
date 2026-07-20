<!-- [skill: clone-website · 组件取证规格] Vokie PrivacyCard/Visual → AgentDock 组件规格（仅规格，不改生产代码） -->
# Privacy Card / Visual 规格

> 来源：https://vokie.com/ `#privacy .privacy-card` + `.privacy-visual`
> 实测：1440×900 / 768×1024 / 390×844；Browser MCP + computed styles。

## 单一目标与 DOM

```html
<div class="privacy-card">
  <div class="privacy-heading">
    <p class="eyebrow">08 / 数据边界</p>
    <h2>先把数据边界<br>讲清楚</h2>
  </div>
  <div class="privacy-copy">
    <p>Vokie 的历史记录主要保存在设备上；根据所用能力，部分转写、摘要或模型请求会调用云端服务。Skill 由你主动安装或卸载，历史查询为只读。</p>
    <a class="text-link" href="/cdn-cgi/l/email-protection#…">询问数据与隐私</a>
  </div>
</div>
<figure class="privacy-visual" aria-hidden="true">
  <img src="/assets/privacy-boundary-BSi1w35N.png" alt=""
    width="1430" height="805" loading="lazy" decoding="async">
</figure>
```

卡内是 heading + copy；visual 为纯装饰，`aria-hidden` 且空 alt。无 `data-reveal`。

## Exact styles

```css
.privacy-card{display:flex;flex-direction:column;justify-content:center;min-width:0;
  color:#090909;background:#a9b1bd;border-radius:30px;padding:72px 64px}
.privacy-layout .eyebrow{color:#090909ad;margin-bottom:28px;
  font:520 12px/1.3 "Geist Mono",monospace;text-transform:uppercase}
.privacy-layout h2{font-size:52px;font-weight:560;line-height:1.05}
.privacy-copy p{max-width:520px;margin:46px 0 32px;color:#090909b8;
  font-size:17px;line-height:1.75}
.text-link{display:inline-flex;align-items:center;min-height:44px;padding:0;
  color:#090909;font-size:14px;opacity:.72;border-bottom:1px solid;
  transition:opacity .18s}
.text-link:hover{opacity:1}
.privacy-section :focus-visible{outline:2px solid #090909;outline-offset:4px}
.privacy-visual{display:flex;justify-content:center;align-items:center;min-width:0;
  min-height:440px;overflow:hidden}
.privacy-visual img{display:block;width:82%;max-width:760px;height:auto;object-fit:contain}
```

桌面左出血：

```css
@media(min-width:901px){
  .privacy-card{
    --privacy-edge:max(var(--page-gutter),calc((100vw - var(--content-width))/2));
    width:calc(100% + var(--privacy-edge));
    margin-left:calc(var(--privacy-edge)*-1);
    padding-left:var(--privacy-edge);
    border-radius:0 30px 30px 0;
  }
}
```

负 margin 让卡片贴视口左缘，补等量 padding 使文字继续对齐 inner；1440 时 edge=40px。左直角、右侧 30px 圆角。

≥901 全局 `body main h2{font-size:30px!important}`，1440 实测 h2 为 30px。

## States

- **Model:** static card/visual + link hover。
- link hover：`opacity:.72 → 1`，`transition:opacity .18s`；1px 下划线常驻。
- focus-visible：2px 深墨 outline、offset 4px，适配浅卡。
- 无 card hover、click、reveal、sticky、scrub；visual 不可聚焦。

## Responsive

| 值 | 1440 | 768 | 390 |
|---|---|---|---|
| card | 左出血；`72px 64px`；radius `0 30 30 0` | 无出血；`54px 40px`；30px | 无出血；`44px 24px`；22px |
| visual | min-height 440px；图 82%/max 760 | min-height 0 | min-height 0 |
| h2 | 30px | 52px | 38px |
| eyebrow | 12px | 12px | 10px |

≤900 关闭出血；≤680 card/visual 由 wrapper 排成单列。

## Reduced motion

`transition-duration:.01ms!important` 使链接 hover 瞬时完成；无其他动画。

## Asset

`/assets/privacy-boundary-BSi1w35N.png`：1430×805、lazy/async、装饰资源，不复制到 AgentDock。

## AgentDock 映射

- eyebrow/h2 对应「08 / 数据边界」「先把数据边界讲清楚」。
- 正文必须覆盖：会话内容/路径/Token 明细留在本机；Automation 仅返回工作区；Accessibility 仅协助支持的审批；遥测仅匿名启动、版本、系统、架构、崩溃元数据。
- 禁止「完全离线」「零上传」等绝对承诺。链接改为产品隐私页/公共反馈入口。
- visual 替换为 AgentDock 权限/数据边界示意，继续保持装饰语义。
