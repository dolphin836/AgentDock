<!-- [skill: go-team-standards · clone-website · 组件取证规格] EthosCapabilityPanels wrapper：仅装配 CapabilitySection 与 CapabilityPanel -->
# EthosCapabilityPanels Wrapper Specification

## Overview
- **唯一目标文件：** `src/components/sections/ethos-capability-panels.tsx`
- **职责：** 维护 active capability 状态、映射四项数据、装配 CapabilitySection/CapabilityPanel。
- **Interaction model：** click-state orchestration。
- **Complexity budget：** builder 只改此目标文件。
- **证据来源：** `https://vokie.com/`，2026-07-20，Browser MCP。

## Builder dependencies
- `capability-section.spec.md` → `src/components/sections/capability-section.tsx`
- `capability-panel.spec.md` → `src/components/sections/capability-panel.tsx`

## Screenshots
- `./assets/ethos-1440-default.png`
- `./assets/ethos-1440-active.png`
- `./assets/ethos-768.png`
- `./assets/ethos-390.png`

## Composition
```tsx
<CapabilitySection heading={heading}>
  {items.map((item, index) => (
    <CapabilityPanel
      key={item.id}
      item={item}
      active={activeIndex === index}
      onActivate={() => setActiveIndex(index)}
    />
  ))}
</CapabilitySection>
```

## State ownership
- `activeIndex`: 桌面 click 激活；默认可为 `null`（四块 25%）。
- 每块 `active` 通过 class 与 `aria-expanded/aria-hidden` 同步。
- ≤767px CSS 关闭手风琴视觉并全部展开；wrapper 不按宽度复制 DOM。

## Content data
- free：自由表达；深色；`/assets/free-expression-*.png`。
- fidelity：忠实整理；青灰；`/assets/faithful-editing-*.png`。
- ready：当下有用；橙色；`/assets/ready-now-*.png`。
- persist：持续可用；近白；精确插画文件名为证据缺口。

## Responsive assembly
- **1440：** 4 panel；默认 25%×4；active 40%，其余 20%。
- **768/390：** CapabilitySection 将容器改纵向；CapabilityPanel 全部可见、无 width transition。
- 精确 section/panel computed 值分别见两个子规格。

## reduced-motion
- wrapper 状态仍切换；CSS 动画由子组件压至 `.01ms`。

## AgentDock mapping
- free→看见状态；fidelity→减少打断；ready→及时响应；persist→返回工作区。
- 不得暗示 Claude Code 支持自动审批；辅助审批仅 Codex/Cursor。

## Evidence gaps
- 第四项原站图片文件名未知；不得猜测。
- wrapper 不重复视觉证据；原 computed/state/responsive 数据已完整迁移到子规格。
