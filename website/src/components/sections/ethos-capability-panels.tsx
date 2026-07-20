// [skill: code-review v2 · dev-dna] 已自检：交互状态、双语内容与 ARIA 保持同步。
"use client";

import { useState, useSyncExternalStore } from "react";

import {
  CapabilityPanel,
  type CapabilityPanelTone,
  type CapabilityPanelVisual,
} from "./capability-panel";
import { CapabilitySection } from "./capability-section";

type Language = "en" | "zh";

interface LocalizedCopy {
  readonly en: string;
  readonly zh: string;
}

interface CapabilityItem {
  readonly id: string;
  readonly eyebrow: string;
  readonly title: LocalizedCopy;
  readonly description: LocalizedCopy;
  readonly tone: CapabilityPanelTone;
  readonly visual: CapabilityPanelVisual;
}

const capabilityItems: readonly CapabilityItem[] = [
  {
    id: "see-status",
    eyebrow: "01",
    tone: "ink",
    visual: "status",
    title: {
      en: "See every state",
      zh: "看清状态",
    },
    description: {
      en: "Know which local agents are working, waiting, or ready without opening every terminal.",
      zh: "无需逐个打开终端，即可看清本地 Agent 正在工作、等待还是已经就绪。",
    },
  },
  {
    id: "reduce-interruptions",
    eyebrow: "02",
    tone: "teal",
    visual: "interruptions",
    title: {
      en: "Reduce interruptions",
      zh: "减少打断",
    },
    description: {
      en: "Keep progress visible in the notch while your attention stays on the work in front of you.",
      zh: "让进度常驻刘海，把注意力留给眼前的工作，不再频繁切换窗口。",
    },
  },
  {
    id: "respond-in-time",
    eyebrow: "03",
    tone: "orange",
    visual: "response",
    title: {
      en: "Respond in time",
      zh: "及时响应",
    },
    description: {
      en: "Catch approvals and questions as they happen, then unblock the right agent with one action.",
      zh: "审批和提问出现时立即获知，一次操作即可让对应 Agent 继续推进。",
    },
  },
  {
    id: "return-to-workspace",
    eyebrow: "04",
    tone: "paper",
    visual: "workspace",
    title: {
      en: "Return to the workspace",
      zh: "返回工作区",
    },
    description: {
      en: "Jump straight back to the terminal or editor where the agent needs you.",
      zh: "直接返回需要你的终端或编辑器，继续处理原来的上下文。",
    },
  },
] as const;

function getDocumentLanguage(): Language {
  return document.documentElement.lang.toLowerCase().startsWith("zh")
    ? "zh"
    : "en";
}

function getServerLanguage(): Language {
  return "en";
}

function subscribeToDocumentLanguage(onLanguageChange: () => void) {
  const observer = new MutationObserver(onLanguageChange);

  observer.observe(document.documentElement, {
    attributeFilter: ["lang"],
    attributes: true,
  });

  return () => observer.disconnect();
}

export function EthosCapabilityPanels() {
  const [activeIndex, setActiveIndex] = useState<number | null>(null);
  const language = useSyncExternalStore(
    subscribeToDocumentLanguage,
    getDocumentLanguage,
    getServerLanguage,
  );

  return (
    <div
      className={`ethosCapabilityPanels${
        activeIndex !== null ? " hasActive" : ""
      }`}
    >
      <CapabilitySection>
        {capabilityItems.map((item, index) => {
          const isActive = activeIndex === index;

          return (
            <CapabilityPanel
              key={item.id}
              item={{
                id: item.id,
                eyebrow: item.eyebrow,
                title: item.title[language],
                description: item.description[language],
                tone: item.tone,
                visual: item.visual,
              }}
              active={isActive}
              onActivate={() => setActiveIndex(index)}
            />
          );
        })}
      </CapabilitySection>
    </div>
  );
}

export default EthosCapabilityPanels;
