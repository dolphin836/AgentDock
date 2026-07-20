// [skill: code-review v2 · dev-dna] 已自检 · P0 修 0 条 / P1 修 0 条 / 通过 14 项
"use client";

import { useRef, type KeyboardEvent } from "react";

import styles from "./voice-tabs.module.css";

export type VoiceStateId =
  | "live-status"
  | "approval-reminder"
  | "waiting-input"
  | "usage-view"
  | "return-workspace";

export interface VoiceState {
  readonly id: VoiceStateId;
  readonly title: string;
  readonly subtitle: string;
  readonly before: string;
  readonly after: string;
  readonly context: string;
  readonly status: string;
}

export interface VoiceTabsProps {
  readonly activeId: VoiceStateId;
  readonly onChange: (id: VoiceStateId) => void;
  readonly items: readonly VoiceState[];
  readonly controlsId?: string;
  readonly label?: string;
  readonly className?: string;
}

export function VoiceTabs({
  activeId,
  onChange,
  items,
  controlsId = "voice-result-stage",
  label = "AgentDock status demo",
  className,
}: VoiceTabsProps) {
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const classNames = className
    ? `${styles.tabList} ${className}`
    : styles.tabList;

  const selectTab = (index: number, moveFocus = false) => {
    const nextTab = items[index];
    const button = tabRefs.current[index];

    if (!nextTab || !button) {
      return;
    }

    onChange(nextTab.id);
    button.scrollIntoView({ block: "nearest", inline: "nearest" });

    if (moveFocus) {
      button.focus();
    }
  };

  const handleKeyDown = (
    event: KeyboardEvent<HTMLButtonElement>,
    currentIndex: number,
  ) => {
    let nextIndex: number | null = null;

    switch (event.key) {
      case "ArrowRight":
        nextIndex = (currentIndex + 1) % items.length;
        break;
      case "ArrowLeft":
        nextIndex = (currentIndex - 1 + items.length) % items.length;
        break;
      case "Home":
        nextIndex = 0;
        break;
      case "End":
        nextIndex = items.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    selectTab(nextIndex, true);
  };

  return (
    <div className={classNames} role="tablist" aria-label={label}>
      {items.map((item, index) => {
        const isActive = item.id === activeId;

        return (
          <button
            ref={(element) => {
              tabRefs.current[index] = element;
            }}
            className={`${styles.tab} ${isActive ? styles.active : ""}`}
            id={`voice-tab-${item.id}`}
            key={item.id}
            type="button"
            role="tab"
            aria-selected={isActive}
            aria-controls={controlsId}
            tabIndex={isActive ? 0 : -1}
            onClick={() => selectTab(index)}
            onKeyDown={(event) => handleKeyDown(event, index)}
          >
            <span className={styles.title}>{item.title}</span>
            <small className={styles.subtitle}>{item.subtitle}</small>
          </button>
        );
      })}
    </div>
  );
}
