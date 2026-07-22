"use client";

import { useEffect, useState } from "react";

import { useLanguage } from "@/hooks/use-language";

import styles from "./hero-content.module.css";

const copyByLanguage = {
  en: {
    eyebrow: "AGENTDOCK · FOR CLAUDE CODE, CODEX & CURSOR",
    titleLines: ["Every agent, in view.", "Your focus stays intact."],
    demo: "See the notch",
    description:
      "AgentDock brings the live status, approvals, and usage of Claude Code, Codex, and Cursor into your macOS notch — glance up and return to the work in progress.",
    statusIdle: "Ready: 3 agents showing in the notch.",
    statusActive:
      "Live: Claude Code running, Codex waiting for approval, Cursor ready.",
  },
  zh: {
    eyebrow: "AGENTDOCK · 支持 CLAUDE CODE、CODEX 与 CURSOR",
    titleLines: ["所有 Agent，都在眼前。", "你的专注，不被打断。"],
    demo: "查看刘海面板",
    description:
      "AgentDock 将 Claude Code、Codex 和 Cursor 的运行状态、审批与用量，汇聚到你的 macOS 刘海。抬眼即见，随时回到正在发生的工作。",
    statusIdle: "准备就绪：3 个 Agent 正在刘海中显示。",
    statusActive:
      "实时状态：Claude Code 运行中，Codex 等待审批，Cursor 已就绪。",
  },
} as const;

export function HeroContent() {
  const language = useLanguage();
  const copy = copyByLanguage[language];

  const [isRevealed, setIsRevealed] = useState(false);
  const [demoActive, setDemoActive] = useState(false);

  useEffect(() => {
    // Reveal on the next frame once client JS confirms; reduced-motion users
    // still land on the revealed state instantly because CSS drops the
    // transition duration.
    const frame = window.requestAnimationFrame(() => setIsRevealed(true));
    return () => window.cancelAnimationFrame(frame);
  }, []);

  const demoStatus = demoActive ? copy.statusActive : copy.statusIdle;

  return (
    <div className={styles.hero} aria-labelledby="hero-title">
      <div className={styles.inner} data-reveal data-revealed={isRevealed}>
        <p className={styles.eyebrow}>{copy.eyebrow}</p>

        <div className={styles.titleBlock}>
          <h1 id="hero-title">
            <span>{copy.titleLines[0]}</span>
            <span>{copy.titleLines[1]}</span>
          </h1>
        </div>

        <div className={styles.bottom}>
          <div className={styles.actions}>
            <a
              className={styles.demo}
              href="#voice"
              onBlur={() => setDemoActive(false)}
              onFocus={() => setDemoActive(true)}
              onMouseEnter={() => setDemoActive(true)}
              onMouseLeave={() => setDemoActive(false)}
            >
              {copy.demo}
            </a>
            <p className={styles.status} aria-live="polite">
              {demoStatus}
            </p>
          </div>

          <p className={styles.description}>{copy.description}</p>
        </div>
      </div>
    </div>
  );
}

export default HeroContent;
