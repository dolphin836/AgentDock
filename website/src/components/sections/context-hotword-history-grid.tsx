"use client";

import { useLanguage, type Language } from "@/hooks/use-language";

import styles from "./context-hotword-history-grid.module.css";

const copy = {
  en: {
    eyebrow: "05 / LOCAL CONTEXT",
    heading: "State stays close, so work never has to be found again",
    body: "AgentDock organises context around the work on this Mac. Come back to the desktop and pick up from the local record.",
    steps: [
      {
        title: "Read local hooks, notify, and Cursor state",
        description:
          "AgentDock reads the local signals available on this Mac and shows running, waiting, and done in one place.",
      },
      {
        title: "Sessions enter the Dock",
        description:
          "When a new local session appears, the Dock keeps its project, current status, and the most recent action needed.",
        running: "Running",
      },
      {
        title: "Run again, restored in place",
        description:
          "Start the same local session again and AgentDock recognises the record, returning it to its previous context.",
        restored: "Restored",
      },
      {
        title: "One local status history",
        description:
          "Review status changes and confirmations on this Mac — know where each agent paused and what comes next.",
        waiting: "Waiting",
        done: "Done",
      },
    ],
  },
  zh: {
    eyebrow: "05 / 本地上下文",
    heading: "状态留在手边，工作不用重新找回",
    body: "AgentDock 只围绕当前这台 Mac 的工作状态组织上下文。每次回到桌面，都能从本地记录接上刚才的进度。",
    steps: [
      {
        title: "接入本地 hooks、notify 与 Cursor 状态",
        description:
          "AgentDock 读取这台 Mac 上可用的本地信号，把运行、等待确认与完成状态放进同一处查看。",
      },
      {
        title: "会话进入 Dock",
        description:
          "新的本地会话出现后，Dock 保留它的项目、当前状态与最近一次需要处理的动作。",
        running: "运行中",
      },
      {
        title: "再次运行，自动归位",
        description:
          "再次启动同一个本地会话时，AgentDock 会识别已有记录，让它回到原来的状态上下文。",
        restored: "已归位",
      },
      {
        title: "统一本地状态历史",
        description:
          "在这台 Mac 上回看状态变更与确认记录，知道每个 Agent 最近停在哪里，也知道下一步该做什么。",
        waiting: "等待确认",
        done: "已完成",
      },
    ],
  },
} as const;

function buildSteps(language: Language) {
  const t = copy[language];
  return [
    {
      index: "01",
      title: t.steps[0].title,
      description: t.steps[0].description,
      visual: (
        <div className={styles.signalList}>
          <span>
            <i className={styles.signalOn} />
            hooks
          </span>
          <span>
            <i className={styles.signalOn} />
            notify
          </span>
          <span>
            <i className={styles.signalWait} />
            cursor
          </span>
        </div>
      ),
    },
    {
      index: "02",
      title: t.steps[1].title,
      description: t.steps[1].description,
      visual: (
        <div className={styles.dockPreview}>
          <span className={styles.dockNotch} />
          <span>Claude · docs-site</span>
          <b>{t.steps[1].running}</b>
        </div>
      ),
    },
    {
      index: "03",
      title: t.steps[2].title,
      description: t.steps[2].description,
      visual: (
        <div className={styles.returnPreview}>
          <span>api-sandbox</span>
          <div>
            <i />
            <i />
            <i className={styles.returnActive} />
          </div>
          <b>{t.steps[2].restored}</b>
        </div>
      ),
    },
    {
      index: "04",
      title: t.steps[3].title,
      description: t.steps[3].description,
      visual: (
        <div className={styles.historyPreview}>
          <span>LOCAL HISTORY</span>
          <div>
            <i />
            <p>
              <b>Cursor</b>
              <em>{t.steps[3].waiting}</em>
            </p>
          </div>
          <div>
            <i className={styles.historyDone} />
            <p>
              <b>Claude</b>
              <em>{t.steps[3].done}</em>
            </p>
          </div>
        </div>
      ),
    },
  ];
}

export function ContextHotwordHistoryGrid() {
  const language = useLanguage();
  const t = copy[language];
  const historySteps = buildSteps(language);

  return (
    <>
      <div className={styles.copy} data-reveal>
        <p className={styles.eyebrow}>{t.eyebrow}</p>
        <h2 id="context-hotword-history-title">{t.heading}</h2>
        <p className={styles.body}>{t.body}</p>
      </div>

      <div className={styles.stack} aria-labelledby="context-hotword-history-title">
        {historySteps.map((step) => (
          <article className={styles.card} data-reveal key={step.index}>
            <span className={styles.index}>{step.index}</span>
            <div className={styles.visual} aria-hidden="true">
              {step.visual}
            </div>
            <h3>{step.title}</h3>
            <p>{step.description}</p>
          </article>
        ))}
      </div>
    </>
  );
}

export default ContextHotwordHistoryGrid;
