"use client";

import { useEffect, useState } from "react";

import { useLanguage, type Language } from "@/hooks/use-language";

import { VoiceResultStage } from "./voice-result-stage";
import {
  type VoiceState as ResolvedVoiceState,
  type VoiceStateId,
  VoiceTabs,
} from "./voice-tabs";
import styles from "./voice-section.module.css";

type LocalizedField = Record<Language, string>;

type VoiceStateData = {
  readonly id: VoiceStateId;
  readonly iconId: string;
  readonly appName: string;
  readonly title: LocalizedField;
  readonly subtitle: LocalizedField;
  readonly before: LocalizedField;
  readonly after: LocalizedField;
  readonly context: LocalizedField;
  readonly status: LocalizedField;
};

export type VoiceStageState = ResolvedVoiceState & {
  readonly iconId: string;
  readonly appName: string;
};

const voiceStates: readonly VoiceStateData[] = [
  {
    id: "live-status",
    iconId: "#voice-icon-live-status",
    appName: "AgentDock",
    title: { en: "Live status", zh: "实时状态" },
    subtitle: {
      en: "See every agent state in the notch.",
      zh: "把分散的终端状态，收进刘海里。",
    },
    before: {
      en: "Claude Code is running, Codex is waiting for approval, Cursor is idle.",
      zh: "Claude Code 在运行，Codex 等待审批，Cursor 已空闲。",
    },
    after: {
      en: "3 agents unified: running, waiting, idle.",
      zh: "3 个 Agent 已统一显示：运行、等待、空闲。",
    },
    context: { en: "Notch overview", zh: "刘海总览" },
    status: { en: "Syncing → Unified", zh: "正在同步 → 已统一" },
  },
  {
    id: "approval-reminder",
    iconId: "#voice-icon-approval",
    appName: "AgentDock",
    title: { en: "Approval alerts", zh: "审批提醒" },
    subtitle: {
      en: "Respond without leaving your work.",
      zh: "写入请求出现时，不必离开眼前的工作。",
    },
    before: {
      en: "Codex requested to write a config file and I hadn't noticed.",
      zh: "Codex 请求写入一个配置文件，我还没看到。",
    },
    after: {
      en: "Codex is waiting for approval.\n\nAllow / Review / Deny",
      zh: "Codex 正在等待审批。\n\nAllow / Review / Deny",
    },
    context: { en: "Permission request", zh: "权限请求" },
    status: { en: "Pending → Answered", zh: "待审批 → 已响应" },
  },
  {
    id: "waiting-input",
    iconId: "#voice-icon-waiting",
    appName: "AgentDock",
    title: { en: "Waiting for input", zh: "等待输入" },
    subtitle: {
      en: "Catch blocked agents before they stall.",
      zh: "Agent 卡住时，提示会直接来到你面前。",
    },
    before: {
      en: "Cursor is waiting on a confirmation, its terminal hidden on another space.",
      zh: "Cursor 在等一个确认，终端窗口藏在其他空间。",
    },
    after: {
      en: "Cursor is waiting for your input.\n\nReply from the notch to continue.",
      zh: "Cursor 正在等待你的输入。\n\n从刘海回复，继续执行。",
    },
    context: { en: "Blocked agent", zh: "阻塞提醒" },
    status: { en: "Waiting → Replied", zh: "等待中 → 已回复" },
  },
  {
    id: "usage-view",
    iconId: "#voice-icon-usage",
    appName: "AgentDock",
    title: { en: "Usage view", zh: "用量视图" },
    subtitle: {
      en: "Compare usage in one place.",
      zh: "不同工具的消耗，放到同一个入口。",
    },
    before: {
      en: "Today's Claude Code, Codex, and Cursor usage is spread across three places.",
      zh: "今天的 Claude Code、Codex 和 Cursor 用量分散在三个地方。",
    },
    after: {
      en: "Usage rolled up for today.\n\nClaude Code · Codex · Cursor",
      zh: "今日用量已汇总。\n\nClaude Code · Codex · Cursor",
    },
    context: { en: "Usage overview", zh: "用量总览" },
    status: { en: "Rolling up → Summarised", zh: "汇总中 → 已汇总" },
  },
  {
    id: "return-workspace",
    iconId: "#voice-icon-return",
    appName: "AgentDock",
    title: { en: "Return to workspace", zh: "返回工作区" },
    subtitle: {
      en: "Jump back to the exact workspace.",
      zh: "从通知回到正在发生的那一行。",
    },
    before: {
      en: "I know an agent needs me, but I can't tell which terminal it's in.",
      zh: "我知道有个 Agent 需要处理，但找不到它在哪个终端。",
    },
    after: {
      en: "Located the Codex session.\n\nBack to the terminal to continue.",
      zh: "已定位到 Codex 会话。\n\n回到终端，继续当前任务。",
    },
    context: { en: "Workspace return", zh: "会话回跳" },
    status: { en: "Locating → Jumped", zh: "定位中 → 已跳转" },
  },
];

const sectionCopy = {
  en: {
    eyebrow: "03 / THE WORKING LOOP",
    title: "See it. Decide. Return.",
    lede: "See each agent's state in the notch, clear approvals and inputs in time, then jump back to the work in progress with one click.",
    tablistLabel: "AgentDock status demo",
  },
  zh: {
    eyebrow: "03 / 工作闭环",
    title: "看见、决定、回到现场",
    lede: "在刘海里看见每个 Agent 的状态，及时完成审批和输入，再一键回到正在发生的工作现场。",
    tablistLabel: "AgentDock 状态演示",
  },
} as const;

function resolveState(
  state: VoiceStateData,
  language: Language,
): VoiceStageState {
  return {
    id: state.id,
    iconId: state.iconId,
    appName: state.appName,
    title: state.title[language],
    subtitle: state.subtitle[language],
    before: state.before[language],
    after: state.after[language],
    context: state.context[language],
    status: state.status[language],
  };
}

export function VoiceSection() {
  const language = useLanguage();
  const copy = sectionCopy[language];

  const [activeId, setActiveId] = useState<VoiceStateId>("live-status");
  const [motionReady, setMotionReady] = useState(false);
  const [revealed, setRevealed] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);

  const items = voiceStates.map((state) => resolveState(state, language));
  const activeState =
    items.find((state) => state.id === activeId) ?? items[0];

  useEffect(() => {
    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const updateMotionPreference = () => setReducedMotion(mediaQuery.matches);

    updateMotionPreference();
    mediaQuery.addEventListener("change", updateMotionPreference);

    return () => mediaQuery.removeEventListener("change", updateMotionPreference);
  }, []);

  useEffect(() => {
    // Defer the reveal to the next frame so setState never runs synchronously
    // inside the effect body. Reduced-motion visitors still see the content
    // immediately because the reveal transition is dropped by CSS.
    const revealFrame = window.requestAnimationFrame(() => {
      if (!reducedMotion) {
        setMotionReady(true);
      }
      setRevealed(true);
    });

    return () => window.cancelAnimationFrame(revealFrame);
  }, [reducedMotion]);

  return (
    <section
      id="voice"
      className={styles.section}
      data-header="light"
      aria-labelledby="voice-heading"
    >
      <div className={styles.intro}>
        <div className={styles.heading}>
          <p className={styles.eyebrow}>{copy.eyebrow}</p>
          <h2 id="voice-heading">{copy.title}</h2>
        </div>
        <p
          className={styles.lede}
          data-reveal
          data-motion-ready={motionReady}
          data-revealed={revealed}
        >
          {copy.lede}
        </p>
      </div>

      <div
        className={styles.focus}
        data-reveal
        data-motion-ready={motionReady}
        data-revealed={revealed}
      >
        <VoiceTabs
          items={items}
          activeId={activeId}
          label={copy.tablistLabel}
          onChange={setActiveId}
        />
        <VoiceResultStage
          state={activeState}
          language={language}
          reducedMotion={reducedMotion}
        />
      </div>
    </section>
  );
}

export default VoiceSection;
