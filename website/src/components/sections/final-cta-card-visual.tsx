"use client";

import { useLanguage } from "@/hooks/use-language";
import { DOWNLOAD_FILENAME } from "@/lib/release";

import styles from "./final-cta-card-visual.module.css";

export type FinalCtaCardVisualProps = {
  downloadUrl: string;
  version: string;
};

const copy = {
  en: {
    eyebrow: "AGENTDOCK · YOUR AGENTS, WITHIN REACH",
    title: "Put your agents in the notch.",
    body: "Keep live status, approvals, and usage close while you stay in your terminal or editor.",
    download: "Download for Mac",
    caption: "3 agents, one glance",
    metadata: (version: string) => `macOS 14+ · Universal · Free · v${version}`,
  },
  zh: {
    eyebrow: "AGENTDOCK · 你的 AGENT，随时可见",
    title: "把你的 Agent 放进刘海。",
    body: "当你专注于终端或编辑器时，把实时状态、审批和用量放在手边。",
    download: "下载 Mac 版",
    caption: "三个 Agent，一眼掌握",
    metadata: (version: string) => `macOS 14+ · 通用版 · 免费 · v${version}`,
  },
} as const;

export function FinalCtaCardVisual({
  downloadUrl,
  version,
}: FinalCtaCardVisualProps) {
  const language = useLanguage();
  const t = copy[language];

  return (
    <>
      <div className={styles.visual} aria-hidden="true">
        <div className={styles.macWindow}>
          <div className={styles.windowChrome}>
            <span className={styles.windowDot} />
            <span className={styles.windowDot} />
            <span className={styles.windowDot} />
          </div>
          <div className={styles.notch}>
            <span className={styles.notchCamera} />
          </div>

          <div className={styles.statusStack}>
            <div className={`${styles.agentRow} ${styles.agentRunning}`}>
              <span className={styles.agentMark}>C</span>
              <span>Claude Code</span>
              <span className={styles.agentState}>running</span>
            </div>
            <div className={`${styles.agentRow} ${styles.agentWaiting}`}>
              <span className={styles.agentMark}>⌘</span>
              <span>Codex</span>
              <span className={styles.agentState}>needs you</span>
            </div>
            <div className={`${styles.agentRow} ${styles.agentReady}`}>
              <span className={styles.agentMark}>⌁</span>
              <span>Cursor</span>
              <span className={styles.agentState}>ready</span>
            </div>
          </div>
          <p className={styles.notchCaption}>{t.caption}</p>
        </div>
      </div>

      <div className={styles.card}>
        <p className={styles.eyebrow}>{t.eyebrow}</p>
        <h2 id="final-cta-heading">{t.title}</h2>
        <p className={styles.body}>{t.body}</p>
        <a className={styles.download} href={downloadUrl} download={DOWNLOAD_FILENAME}>
          {t.download} <span className={styles.cursor}>_</span>
        </a>
        <p className={styles.metadata}>{t.metadata(version)}</p>
      </div>
    </>
  );
}

export default FinalCtaCardVisual;
