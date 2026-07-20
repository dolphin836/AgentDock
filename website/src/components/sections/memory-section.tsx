"use client";

import { useLanguage } from "@/hooks/use-language";

import styles from "./memory-section.module.css";

const copy = {
  en: {
    eyebrow: "06 / SESSION HISTORY",
    heading: "See what each agent has done",
    description:
      "AgentDock keeps session state and approval history on your device, so you can review the running, waiting, and confirmation records of Claude, Codex, and Cursor.",
    ariaLabel:
      "Illustrative AgentDock local session and approval timeline interface",
    today: "Today",
    localBadge: "Stored on this Mac only",
    footerCount: "3 local records",
    footerNote: "Approval records kept locally",
    items: [
      { state: "Done", detail: "Session ended, local state saved" },
      { state: "Approved", detail: "Allowed to run type checks" },
      { state: "Waiting", detail: "Requesting confirmation of file changes" },
    ],
  },
  zh: {
    eyebrow: "06 / 状态历史",
    heading: "回看每个 Agent 做过什么",
    description:
      "AgentDock 在设备本地保留会话状态与审批历史，方便你回看 Claude、Codex 和 Cursor 的运行、等待与确认记录。",
    ariaLabel: "AgentDock 本地会话与审批时间线界面示意",
    today: "今天",
    localBadge: "仅保存在此 Mac",
    footerCount: "3 条本地记录",
    footerNote: "审批记录保存在本地",
    items: [
      { state: "已完成", detail: "会话结束，本地状态已保存" },
      { state: "已批准", detail: "允许运行类型检查" },
      { state: "等待中", detail: "请求确认文件修改" },
    ],
  },
} as const;

const timelineBase = [
  { time: "10:42", agent: "Claude", project: "docs-site", tone: "complete" },
  { time: "10:18", agent: "Codex", project: "api-sandbox", tone: "approved" },
  { time: "09:56", agent: "Cursor", project: "release-notes", tone: "waiting" },
] as const;

export function MemorySection() {
  const language = useLanguage();
  const t = copy[language];

  const timelineItems = timelineBase.map((item, index) => ({
    ...item,
    state: t.items[index].state,
    detail: t.items[index].detail,
  }));

  return (
    <section
      id="memory"
      className={styles.section}
      data-header="dark"
      aria-labelledby="memory-heading"
    >
      <div className={styles.inner}>
        <div className={styles.heading} data-reveal>
          <p className={styles.eyebrow}>{t.eyebrow}</p>
          <h2 id="memory-heading">{t.heading}</h2>
          <p className={styles.description}>{t.description}</p>
        </div>

        <div
          className={styles.productMock}
          role="img"
          aria-label={t.ariaLabel}
        >
          <div className={styles.mockShell}>
            <aside className={styles.mockRail} aria-hidden="true">
              <span className={styles.railMark}>AD</span>
              <span className={`${styles.railDot} ${styles.railDotActive}`} />
              <span className={styles.railDot} />
              <span className={styles.railDot} />
            </aside>

            <div className={styles.mockMain}>
              <header className={styles.mockHeader}>
                <div>
                  <span className={styles.mockKicker}>LOCAL HISTORY</span>
                  <strong>{t.today}</strong>
                </div>
                <span className={styles.localBadge}>
                  <span />
                  {t.localBadge}
                </span>
              </header>

              <div className={styles.timeline}>
                {timelineItems.map((item) => (
                  <article className={styles.timelineItem} key={`${item.time}-${item.agent}`}>
                    <time>{item.time}</time>
                    <span
                      className={`${styles.timelineNode} ${styles[item.tone]}`}
                      aria-hidden="true"
                    />
                    <div className={styles.event}>
                      <div className={styles.eventTopline}>
                        <strong>{item.agent}</strong>
                        <span>{item.project}</span>
                        <em className={styles[item.tone]}>{item.state}</em>
                      </div>
                      <p>{item.detail}</p>
                    </div>
                  </article>
                ))}
              </div>

              <footer className={styles.mockFooter}>
                <span>{t.footerCount}</span>
                <span>{t.footerNote}</span>
              </footer>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default MemorySection;
