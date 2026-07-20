"use client";

// [skill: code-review v2 · dev-dna] 已自检：组件 API 明确、实现局部且无额外依赖。

import { useId, useState } from "react";

import styles from "./outcomes-accordion.module.css";

export type OutcomesLanguage = "en" | "zh-CN";

type LocalizedText = Record<OutcomesLanguage, string>;

export interface OutcomeItem {
  id: string;
  index: string;
  title: LocalizedText;
  subtitle: LocalizedText;
  mock: "status" | "approval" | "usage";
}

export interface OutcomesAccordionContent {
  eyebrow: LocalizedText;
  title: LocalizedText;
  description: LocalizedText;
  items: OutcomeItem[];
}

export interface OutcomesAccordionProps {
  language?: OutcomesLanguage;
  content?: OutcomesAccordionContent;
}

export const outcomesAccordionContent: OutcomesAccordionContent = {
  eyebrow: {
    en: "04 / ONE NOTCH, COMPLETE CONTROL",
    "zh-CN": "04 / 一个刘海，多种掌控",
  },
  title: {
    en: "Your agents never leave your sight",
    "zh-CN": "所有 Agent，始终一目了然",
  },
  description: {
    en: "See what is happening, respond when needed, and keep usage in view.",
    "zh-CN": "实时掌握进度，在需要时响应，并随时查看用量。",
  },
  items: [
    {
      id: "live-status",
      index: "01",
      title: { en: "Live status", "zh-CN": "实时状态" },
      subtitle: {
        en: "See which agents are running, waiting, or idle.",
        "zh-CN": "一眼看清 Agent 正在运行、等待还是空闲。",
      },
      mock: "status",
    },
    {
      id: "approval-alerts",
      index: "02",
      title: { en: "Approval alerts", "zh-CN": "审批提醒" },
      subtitle: {
        en: "Allow, review, or deny without losing your place.",
        "zh-CN": "无需离开当前工作，即可允许、审查或拒绝。",
      },
      mock: "approval",
    },
    {
      id: "usage-view",
      index: "03",
      title: { en: "Usage view", "zh-CN": "用量视图" },
      subtitle: {
        en: "Keep every agent's limits in one clear view.",
        "zh-CN": "在同一入口清晰查看各 Agent 的用量与额度。",
      },
      mock: "usage",
    },
  ],
};

function ProductMock({
  type,
  language,
}: {
  type: OutcomeItem["mock"];
  language: OutcomesLanguage;
}) {
  const isChinese = language === "zh-CN";

  return (
    <span className={styles.mockShell} aria-hidden="true">
      <span className={styles.mockTopbar}>
        <span className={styles.trafficLights}>
          <i />
          <i />
          <i />
        </span>
        <span className={styles.notch}>
          <span className={styles.notchMark}>A</span>
          <span>AgentDock</span>
        </span>
        <span className={styles.mockTime}>09:41</span>
      </span>

      {type === "status" && (
        <span className={styles.mockBody}>
          <span className={styles.mockKicker}>
            {isChinese ? "实时工作区" : "LIVE WORKSPACE"}
          </span>
          <span className={styles.statusList}>
            <span className={styles.statusRow}>
              <span className={`${styles.agentBadge} ${styles.claude}`}>C</span>
              <span className={styles.agentCopy}>
                <b>Claude Code</b>
                <small>{isChinese ? "正在更新组件" : "Updating component"}</small>
              </span>
              <span className={`${styles.statusPill} ${styles.running}`}>
                {isChinese ? "运行中" : "Running"}
              </span>
            </span>
            <span className={styles.statusRow}>
              <span className={`${styles.agentBadge} ${styles.codex}`}>X</span>
              <span className={styles.agentCopy}>
                <b>Codex</b>
                <small>{isChinese ? "等待审批" : "Waiting for approval"}</small>
              </span>
              <span className={`${styles.statusPill} ${styles.waiting}`}>
                {isChinese ? "等待" : "Waiting"}
              </span>
            </span>
            <span className={styles.statusRow}>
              <span className={`${styles.agentBadge} ${styles.cursor}`}>›_</span>
              <span className={styles.agentCopy}>
                <b>Cursor</b>
                <small>{isChinese ? "工作区已同步" : "Workspace synced"}</small>
              </span>
              <span className={styles.statusPill}>
                {isChinese ? "空闲" : "Idle"}
              </span>
            </span>
          </span>
        </span>
      )}

      {type === "approval" && (
        <span className={`${styles.mockBody} ${styles.approvalBody}`}>
          <span className={styles.mockKicker}>
            {isChinese ? "需要你确认" : "YOUR ATTENTION"}
          </span>
          <span className={styles.approvalCard}>
            <span className={styles.approvalIcon}>?</span>
            <span className={styles.approvalCopy}>
              <b>{isChinese ? "审批请求" : "Approval requested"}</b>
              <small>
                {isChinese
                  ? "Agent 希望运行本地检查。"
                  : "An agent wants to run local checks."}
              </small>
            </span>
            <span className={styles.approvalMeta}>
              {isChinese ? "等待中" : "Waiting"}
            </span>
          </span>
          <span className={styles.actionRow}>
            <span className={styles.allowAction}>
              {isChinese ? "允许" : "Allow"}
            </span>
            <span>{isChinese ? "审查" : "Review"}</span>
            <span>{isChinese ? "拒绝" : "Deny"}</span>
          </span>
        </span>
      )}

      {type === "usage" && (
        <span className={styles.mockBody}>
          <span className={styles.usageHeading}>
            <span>
              <span className={styles.mockKicker}>
                {isChinese ? "本周用量" : "WEEKLY USAGE"}
              </span>
              <b>{isChinese ? "额度概览" : "Limits overview"}</b>
            </span>
            <span className={styles.periodPill}>
              {isChinese ? "7 天" : "7 days"}
            </span>
          </span>
          <span className={styles.usageList}>
            {[
              ["Claude Code", "68%", styles.usageClaude],
              ["Codex", "42%", styles.usageCodex],
              ["Cursor", "24%", styles.usageCursor],
            ].map(([name, value, barClass]) => (
              <span className={styles.usageRow} key={name}>
                <span className={styles.usageLabel}>
                  <b>{name}</b>
                  <small>{value}</small>
                </span>
                <span className={styles.usageTrack}>
                  <i className={barClass} />
                </span>
              </span>
            ))}
          </span>
        </span>
      )}
    </span>
  );
}

export function OutcomesAccordion({
  language = "en",
  content = outcomesAccordionContent,
}: OutcomesAccordionProps) {
  const instanceId = useId();
  const [activeId, setActiveId] = useState(content.items[0]?.id ?? "");
  const titleId = `${instanceId}-outcomes-title`;

  return (
    <section className={styles.section} aria-labelledby={titleId}>
      <div className={styles.inner}>
        <header className={styles.heading}>
          <p className={styles.eyebrow}>{content.eyebrow[language]}</p>
          <h2 id={titleId}>{content.title[language]}</h2>
          <p className={styles.description}>
            {content.description[language]}
          </p>
        </header>

        <div className={styles.accordion}>
          {content.items.map((item) => {
            const isOpen = activeId === item.id;
            const triggerId = `${instanceId}-outcome-trigger-${item.id}`;
            const detailId = `${instanceId}-outcome-detail-${item.id}`;

            return (
              <article className={styles.item} key={item.id}>
                <button
                  className={styles.trigger}
                  id={triggerId}
                  type="button"
                  aria-expanded={isOpen}
                  aria-controls={detailId}
                  onClick={() => setActiveId(item.id)}
                >
                  <span className={styles.index}>{item.index}</span>
                  <span className={styles.copy}>
                    <span className={styles.itemTitle}>
                      {item.title[language]}
                    </span>
                    <small className={styles.subtitle}>
                      {item.subtitle[language]}
                    </small>
                  </span>
                  <i className={styles.toggle} aria-hidden="true" />
                </button>
                <div
                  className={`${styles.detail} ${
                    isOpen ? styles.detailOpen : ""
                  }`}
                  id={detailId}
                  role="region"
                  aria-labelledby={triggerId}
                  aria-hidden={!isOpen}
                >
                  <span className={styles.detailClip}>
                    <span className={styles.media}>
                      <ProductMock type={item.mock} language={language} />
                    </span>
                  </span>
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export default OutcomesAccordion;
