"use client";

import { useId } from "react";

import styles from "./capability-panel.module.css";

export type CapabilityPanelTone = "ink" | "teal" | "orange" | "paper";
export type CapabilityPanelVisual =
  | "status"
  | "interruptions"
  | "response"
  | "workspace";

export interface CapabilityPanelItem {
  readonly id: string;
  readonly eyebrow: string;
  readonly title: string;
  readonly description: string;
  readonly tone: CapabilityPanelTone;
  readonly visual: CapabilityPanelVisual;
}

export interface CapabilityPanelProps {
  readonly item: CapabilityPanelItem;
  readonly active: boolean;
  readonly onActivate: (id: string) => void;
}

function PanelVisual({ type }: { type: CapabilityPanelVisual }) {
  if (type === "status") {
    return (
      <div className={styles.agentDockUi} aria-hidden="true">
        <div className={styles.uiTopbar}>
          <span className={styles.uiMark}>AD</span>
          <span>AgentDock / Today</span>
          <span className={styles.localSignal}>LOCAL</span>
        </div>
        <div className={styles.statusHeader}>
          <span>ACTIVE AGENTS</span>
          <strong>3 running</strong>
        </div>
        <div className={styles.agentRows}>
          {[
            ["Claude", "Refining component", "RUNNING"],
            ["Cursor", "Reviewing typecheck", "WATCHING"],
            ["Codex", "Preparing summary", "IDLE"],
          ].map(([agent, task, state]) => (
            <div className={styles.agentRow} key={agent}>
              <span className={styles.agentAvatar}>{agent.slice(0, 1)}</span>
              <span className={styles.agentTask}>
                <strong>{agent}</strong>
                <small>{task}</small>
              </span>
              <span className={styles.agentState}>{state}</span>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (type === "interruptions") {
    return (
      <div className={`${styles.agentDockUi} ${styles.quietUi}`} aria-hidden="true">
        <div className={styles.uiTopbar}>
          <span className={styles.uiMark}>AD</span>
          <span>Focus routing</span>
          <span className={styles.localSignal}>QUIET MODE</span>
        </div>
        <div className={styles.focusScore}>
          <span>UNINTERRUPTED TIME</span>
          <strong>48 min</strong>
          <i />
        </div>
        <div className={styles.routedAlert}>
          <span className={styles.alertDot} />
          <span>
            <strong>2 updates held back</strong>
            <small>They can wait until this task is done.</small>
          </span>
        </div>
        <div className={styles.timeline}>
          <i />
          <i />
          <i />
          <i />
          <i />
          <i />
        </div>
      </div>
    );
  }

  if (type === "response") {
    return (
      <div className={`${styles.agentDockUi} ${styles.approvalUi}`} aria-hidden="true">
        <div className={styles.uiTopbar}>
          <span className={styles.uiMark}>AD</span>
          <span>Approval boundary</span>
          <span className={styles.localSignal}>1 REQUEST</span>
        </div>
        <div className={styles.requestKicker}>ACTION NEEDS YOUR OK</div>
        <div className={styles.requestCard}>
          <span className={styles.requestIcon}>↗</span>
          <span>
            <strong>Write 2 local files</strong>
            <small>Claude wants to update the component and styles.</small>
          </span>
        </div>
        <div className={styles.scopeRow}>
          <span>Scope</span>
          <strong>src/components/sections</strong>
        </div>
        <div className={styles.actionButtons}>
          <span>Review</span>
          <b>Allow once</b>
        </div>
      </div>
    );
  }

  return (
    <div className={`${styles.agentDockUi} ${styles.workspaceUi}`} aria-hidden="true">
      <div className={styles.uiTopbar}>
        <span className={styles.uiMark}>AD</span>
        <span>Workspace return</span>
        <span className={styles.localSignal}>READY</span>
      </div>
      <div className={styles.workspaceLabel}>
        <span>RETURNING TO</span>
        <strong>capability-panel.tsx</strong>
      </div>
      <div className={styles.editorMock}>
        <span>01&nbsp; export function CapabilityPanel(</span>
        <span>02&nbsp; &nbsp;{`{ item, active, onActivate }`}</span>
        <span>03&nbsp; ) {`{`}</span>
        <span>04&nbsp; &nbsp;return &lt;section&gt;…</span>
      </div>
      <div className={styles.returnFooter}>
        <span><i /> Agent response delivered</span>
        <strong>Open workspace ↗</strong>
      </div>
    </div>
  );
}

export function CapabilityPanel({
  item,
  active,
  onActivate,
}: CapabilityPanelProps) {
  const instanceId = useId();
  const contentId = `${instanceId}-${item.id}-content`;

  return (
    <article
      className={`${styles.panel} ${active ? styles.active : ""}`}
      data-tone={item.tone}
    >
      <button
        className={styles.trigger}
        type="button"
        aria-expanded={active}
        aria-controls={contentId}
        onClick={() => onActivate(item.id)}
      >
        <span className={styles.triggerIndex}>{item.eyebrow}</span>
        <span className={styles.triggerTitle}>{item.title}</span>
        <span className={styles.triggerArrow} aria-hidden="true">↗</span>
      </button>

      <div className={styles.mobileHeading}>
        <p>{item.eyebrow}</p>
        <h3>{item.title}</h3>
      </div>

      <div className={styles.surface} id={contentId} role="region">
        <div className={styles.content}>
          <div className={styles.copy}>
            <p className={styles.eyebrow}>{item.eyebrow}</p>
            <h3>{item.title}</h3>
            <p className={styles.description}>{item.description}</p>
          </div>
          <PanelVisual type={item.visual} />
        </div>
      </div>
    </article>
  );
}

export default CapabilityPanel;
