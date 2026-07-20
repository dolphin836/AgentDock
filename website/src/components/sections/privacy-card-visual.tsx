"use client";

import { useLanguage, type Language } from "@/hooks/use-language";

import styles from "./privacy-card-visual.module.css";

type BoundaryTone = "local" | "review" | "telemetry";

const copy = {
  en: {
    eyebrow: "07 / DATA BOUNDARY",
    title: "Your work stays on your Mac.",
    body: "Session content, file paths, and token details stay on your Mac. Apple Events only return you to the right workspace, and accessibility assists supported approvals for Codex and Cursor. Limited telemetry — launch, version, system, architecture, and crash metadata keyed to a random installation-level identifier — never includes session content or paths.",
    link: "Read the data boundary",
    figCaption: "On-device data boundary",
    ariaLabel:
      "Data boundary diagram: session, paths, and tokens stay on the Mac; the local socket and Apple Events are permission-gated; telemetry excludes session content and paths.",
    items: [
      { label: "LOCAL SOCKET", detail: "Mac ↔ AgentDock", tone: "local" },
      { label: "APPLE EVENTS", detail: "Requires your approval", tone: "review" },
      {
        label: "TELEMETRY",
        detail: "Install ID · launch · crash metadata",
        tone: "telemetry",
      },
    ],
  },
  zh: {
    eyebrow: "07 / 数据边界",
    title: "你的工作留在你的 Mac 上。",
    body: "会话内容、工作区路径和 token 留在本机。Apple Events 仅用于带你回到正确的工作区；辅助功能仅协助 Codex 与 Cursor 完成受支持的审批。有限遥测——启动、版本、系统、架构与崩溃元数据，仅关联一个随机的安装级标识——不含会话内容或路径。",
    link: "查看数据边界",
    figCaption: "本机数据边界",
    ariaLabel:
      "数据边界示意：会话、路径和 token 留在 Mac；本地 socket 与 Apple Events 受权限约束，遥测不含会话内容或路径。",
    items: [
      { label: "LOCAL SOCKET", detail: "Mac ↔ AgentDock", tone: "local" },
      { label: "APPLE EVENTS", detail: "需你的批准", tone: "review" },
      {
        label: "TELEMETRY",
        detail: "安装标识 · 启动 · 崩溃元数据",
        tone: "telemetry",
      },
    ],
  },
} satisfies Record<
  Language,
  {
    eyebrow: string;
    title: string;
    body: string;
    link: string;
    figCaption: string;
    ariaLabel: string;
    items: ReadonlyArray<{ label: string; detail: string; tone: BoundaryTone }>;
  }
>;

export function PrivacyCardVisual() {
  const language = useLanguage();
  const t = copy[language];

  return (
    <>
      <div className={styles.card}>
        <p className={styles.eyebrow}>{t.eyebrow}</p>
        <h2 id="privacy-card-title">{t.title}</h2>
        <p className={styles.copy}>{t.body}</p>
        <a className={styles.link} href="#privacy">
          {t.link}
          <span aria-hidden="true">↗</span>
        </a>
      </div>

      <figure className={styles.visual} role="img" aria-label={t.ariaLabel}>
        <div className={styles.diagram}>
          <div className={styles.diagramHeader}>
            <span>DATA BOUNDARY</span>
            <span className={styles.secureMark}>LOCAL</span>
          </div>

          <div className={styles.mac}>
            <div className={styles.macScreen}>
              <div className={styles.macBar}>
                <span />
                <span />
                <span />
                <b>AGENTDOCK</b>
              </div>
              <div className={styles.macContent}>
                <span>session content</span>
                <span>workspace path</span>
                <span>token</span>
              </div>
              <p>STAYS ON THIS MAC</p>
            </div>
            <div className={styles.macBase} />
          </div>

          <div className={styles.boundaryLine} aria-hidden="true">
            <span />
          </div>

          <div className={styles.connections}>
            {t.items.map((item) => (
              <div className={styles.connection} key={item.label}>
                <span className={`${styles.status} ${styles[item.tone]}`} />
                <div>
                  <strong>{item.label}</strong>
                  <small>{item.detail}</small>
                </div>
              </div>
            ))}
          </div>

          <p className={styles.diagramNote}>
            telemetry excludes session content and workspace paths
          </p>
        </div>
        <figcaption>{t.figCaption}</figcaption>
      </figure>
    </>
  );
}

export default PrivacyCardVisual;
