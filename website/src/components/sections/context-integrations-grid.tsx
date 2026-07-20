"use client";

import { useLanguage } from "@/hooks/use-language";

import styles from "./context-integrations-grid.module.css";

const copy = {
  en: {
    eyebrow: "04 / INTEGRATIONS",
    heading: "Connect locally. Keep control.",
    description:
      "Set up integrations from AgentDock, then keep working in the tools you already use. Each integration has its own local mechanism.",
    boundary:
      "Boundary: Claude Code is never auto-approved; assisted approval applies to Codex and Cursor only.",
    cards: [
      {
        title: "Claude Code",
        body: "Registers AgentDock hooks and a status line. Your prior settings.json is backed up before installation and can be restored on uninstall.",
        mark: "HOOKS\nSTATUS",
      },
      {
        title: "Codex",
        body: "Adds a notify entry and follows the local rollout JSONL to infer intermediate session state.",
        mark: "LOCAL\nJSONL",
      },
      {
        title: "Cursor",
        body: "Surfaces agent status and usage so each conversation and run isn't buried in an editor tab.",
        mark: "USAGE\nSTATE",
      },
      {
        title: "Return to work",
        body: "Click a notification to return to iTerm2, Terminal, or VS Code and keep typing, approving, and moving forward.",
        mark: "RETURN\nTO WORK",
      },
    ],
  },
  zh: {
    eyebrow: "04 / 集成",
    heading: "本地接入，始终可控。",
    description:
      "在 AgentDock 中完成集成后，继续使用你原本的工具。每种集成都有各自的本地接入方式。",
    boundary: "边界：Claude Code 不自动审批；协助审批仅适用于 Codex 与 Cursor。",
    cards: [
      {
        title: "Claude Code",
        body: "注册 AgentDock hooks 和状态栏。安装前会备份原有 settings.json，卸载时可恢复。",
        mark: "HOOKS\nSTATUS",
      },
      {
        title: "Codex",
        body: "添加 notify 配置，并跟随本地 rollout JSONL 推断会话中间状态。",
        mark: "LOCAL\nJSONL",
      },
      {
        title: "Cursor",
        body: "汇总 Agent 的运行状态和用量，让每段对话、每次执行的进度不再藏在编辑器标签页里。",
        mark: "USAGE\nSTATE",
      },
      {
        title: "回到现场",
        body: "点击通知即可回到 iTerm2、Terminal 或 VS Code，在原来的窗口继续输入、确认和推进。",
        mark: "RETURN\nTO WORK",
      },
    ],
  },
} as const;

export function ContextIntegrationsGrid() {
  const language = useLanguage();
  const t = copy[language];

  return (
    <section
      className={styles.section}
      id="integrations"
      data-header="dark"
      aria-labelledby="integrations-heading"
    >
      <div className={styles.inner}>
        <div className={styles.copy} data-reveal>
          <p className={styles.eyebrow}>{t.eyebrow}</p>
          <h2 id="integrations-heading">{t.heading}</h2>
          <p className={styles.description}>{t.description}</p>
          <p className={styles.boundary}>{t.boundary}</p>
        </div>

        <div className={styles.cards}>
          {t.cards.map((integration, index) => (
            <article className={styles.card} data-reveal key={integration.title}>
              <span className={styles.watermark} aria-hidden="true">
                {integration.mark}
              </span>
              <span className={styles.index}>{`0${index + 1}`}</span>
              <h3>{integration.title}</h3>
              <p>{integration.body}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

export default ContextIntegrationsGrid;
