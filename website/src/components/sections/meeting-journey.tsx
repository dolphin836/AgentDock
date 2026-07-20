"use client";

import { useEffect, useRef } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

import { useLanguage, type Language } from "@/hooks/use-language";

import styles from "./meeting-journey.module.css";

gsap.registerPlugin(ScrollTrigger);

type Slide = {
  index: string;
  title: string;
  body: string;
  media: React.ReactNode;
};

/** 桌面横向 pin 生效条件: 宽 >900 且高 >=700 且允许动效. */
const DESKTOP_QUERY =
  "(min-width: 901px) and (min-height: 700px) and (prefers-reduced-motion: no-preference)";

const mockCopy = {
  en: {
    permBar: "AgentDock · Local setup",
    permTitle: "Grant access to local tools",
    permDesc:
      "AgentDock reads agent state through local hooks — no cloud account required.",
    permRow1: "Terminal · command hook",
    permRow2: "Notification Center",
    permPending: "Pending",
    permLater: "Later",
    permAllow: "Allow",
    statusBar: "Notch · Live status",
    stRunning: "Running",
    stWaiting: "Waiting for approval",
    stIdle: "Idle",
    apprBar: "Approval · Usage",
    apprRequest: "Codex requests write to src/",
    returnBar: "Return to workspace",
    jumpTerminal: "Back to terminal →",
    jumpEditor: "Back to editor →",
    jumpSession: "Open session →",
  },
  zh: {
    permBar: "AgentDock · 本地接入",
    permTitle: "授予本地工具访问权限",
    permDesc: "AgentDock 通过本地 hooks 读取 Agent 运行状态，无需云端账号。",
    permRow1: "Terminal · 命令钩子",
    permRow2: "通知中心",
    permPending: "待确认",
    permLater: "稍后",
    permAllow: "允许接入",
    statusBar: "刘海 · 实时状态",
    stRunning: "运行中",
    stWaiting: "等待审批",
    stIdle: "空闲",
    apprBar: "审批 · 用量",
    apprRequest: "Codex 请求写入 src/",
    returnBar: "返回工作区",
    jumpTerminal: "跳回终端 →",
    jumpEditor: "跳回编辑器 →",
    jumpSession: "打开会话 →",
  },
} as const;

const sectionCopy = {
  en: {
    eyebrow: "02 / THE JOURNEY",
    title: "From setup to workspace return, AgentDock keeps every state in view.",
    lede: "After install, grant local permissions; the notch shows each agent's running, approval, and usage state, and jumps you back to the right terminal or editor when needed.",
    slides: [
      {
        title: "Connect local permissions",
        body: "Connect through local hooks — no cloud account, notifications generated on this Mac.",
      },
      {
        title: "See live status",
        body: "The notch unifies Claude Code, Codex, and Cursor as running, waiting, or idle.",
      },
      {
        title: "Approvals and usage",
        body: "Get Allow / Review / Deny prompts and check each agent's usage in one place.",
      },
      {
        title: "Return to workspace",
        body: "Click a session to jump straight back to its terminal or editor, with less context switching.",
      },
    ],
  },
  zh: {
    eyebrow: "02 / 使用旅程",
    title: "从接入到回到工作区，AgentDock 一路把状态摆在眼前。",
    lede: "安装后授予本地权限，刘海即时呈现每个 Agent 的运行、审批与用量，需要时一键跳回对应终端或编辑器。",
    slides: [
      {
        title: "接入本地权限",
        body: "通过本地 hooks 接入，无需云端账号，通知在本机产生。",
      },
      {
        title: "看见实时状态",
        body: "刘海统一显示 Claude Code、Codex、Cursor 的运行、等待与空闲。",
      },
      {
        title: "审批与用量",
        body: "收到 Allow / Review / Deny 提醒，并在同一入口查看各 Agent 用量。",
      },
      {
        title: "返回工作区",
        body: "点击会话直接跳回对应终端或编辑器，减少注意力切换。",
      },
    ],
  },
} as const;

/** HTML 产品 mock — AgentDock 原创界面, 不复制 Vokie 图片, 不含 PII. */

function PermissionMock({ language }: { language: Language }) {
  const t = mockCopy[language];
  return (
    <div className={styles.mock}>
      <div className={styles.mockBar}>
        <span className={styles.mockDots}>
          <span />
          <span />
          <span />
        </span>
        {t.permBar}
      </div>
      <div className={styles.mockPanel}>
        <strong>{t.permTitle}</strong>
        <span style={{ color: "rgb(246 248 248 / 55%)" }}>{t.permDesc}</span>
        <div className={styles.mockRow}>
          <span className={styles.statusLabel}>{t.permRow1}</span>
          <span className={`${styles.pill} ${styles.pillReview}`}>
            {t.permPending}
          </span>
        </div>
        <div className={styles.mockRow}>
          <span className={styles.statusLabel}>{t.permRow2}</span>
          <span className={`${styles.pill} ${styles.pillReview}`}>
            {t.permPending}
          </span>
        </div>
      </div>
      <div className={styles.mockButtons}>
        <button type="button" className={styles.btn}>
          {t.permLater}
        </button>
        <button type="button" className={`${styles.btn} ${styles.btnPrimary}`}>
          {t.permAllow}
        </button>
      </div>
    </div>
  );
}

function StatusMock({ language }: { language: Language }) {
  const t = mockCopy[language];
  return (
    <div className={styles.mock}>
      <div className={styles.mockBar}>{t.statusBar}</div>
      <div className={styles.mockPanel}>
        <div className={styles.mockRow}>
          <span className={styles.mockAgent}>
            <span className={`${styles.statusDot} ${styles.statusRun}`} />
            Claude Code
          </span>
          <span className={styles.statusLabel}>{t.stRunning}</span>
        </div>
        <div className={styles.mockRow}>
          <span className={styles.mockAgent}>
            <span className={`${styles.statusDot} ${styles.statusWait}`} />
            Codex
          </span>
          <span className={styles.statusLabel}>{t.stWaiting}</span>
        </div>
        <div className={styles.mockRow}>
          <span className={styles.mockAgent}>
            <span className={`${styles.statusDot} ${styles.statusIdle}`} />
            Cursor
          </span>
          <span className={styles.statusLabel}>{t.stIdle}</span>
        </div>
      </div>
    </div>
  );
}

function ApprovalMock({ language }: { language: Language }) {
  const t = mockCopy[language];
  return (
    <div className={styles.mock}>
      <div className={styles.mockBar}>{t.apprBar}</div>
      <div className={styles.mockPanel}>
        <div className={styles.mockRow}>
          <span className={styles.statusLabel}>{t.apprRequest}</span>
        </div>
        <div className={styles.mockButtons} style={{ marginTop: 0 }}>
          <button type="button" className={`${styles.btn} ${styles.btnPrimary}`}>
            Allow
          </button>
          <button type="button" className={styles.btn}>
            Review
          </button>
          <button type="button" className={styles.btn}>
            Deny
          </button>
        </div>
      </div>
      <div className={styles.mockPanel}>
        <div className={styles.usageRow}>
          <div className={styles.usageMeta}>
            <span>Claude Code</span>
            <span>62%</span>
          </div>
          <div className={styles.usageTrack}>
            <span className={styles.usageFill} style={{ width: "62%" }} />
          </div>
        </div>
        <div className={styles.usageRow}>
          <div className={styles.usageMeta}>
            <span>Codex</span>
            <span>38%</span>
          </div>
          <div className={styles.usageTrack}>
            <span className={styles.usageFill} style={{ width: "38%" }} />
          </div>
        </div>
      </div>
    </div>
  );
}

function ReturnMock({ language }: { language: Language }) {
  const t = mockCopy[language];
  return (
    <div className={styles.mock}>
      <div className={styles.mockBar}>{t.returnBar}</div>
      <div className={styles.jumpRow}>
        <span className={styles.mockAgent}>
          <span className={`${styles.statusDot} ${styles.statusRun}`} />
          Claude Code
        </span>
        <span className={styles.jumpTarget}>{t.jumpTerminal}</span>
      </div>
      <div className={styles.jumpRow}>
        <span className={styles.mockAgent}>
          <span className={`${styles.statusDot} ${styles.statusWait}`} />
          Codex
        </span>
        <span className={styles.jumpTarget}>{t.jumpEditor}</span>
      </div>
      <div className={styles.jumpRow}>
        <span className={styles.mockAgent}>
          <span className={`${styles.statusDot} ${styles.statusIdle}`} />
          Cursor
        </span>
        <span className={styles.jumpTarget}>{t.jumpSession}</span>
      </div>
    </div>
  );
}

function buildSlides(language: Language): Slide[] {
  const copy = sectionCopy[language].slides;
  const media = [
    <PermissionMock key="perm" language={language} />,
    <StatusMock key="status" language={language} />,
    <ApprovalMock key="approval" language={language} />,
    <ReturnMock key="return" language={language} />,
  ];

  return copy.map((slide, index) => ({
    index: `0${index + 1}`,
    title: slide.title,
    body: slide.body,
    media: media[index],
  }));
}

export function MeetingJourney() {
  const language = useLanguage();
  const copy = sectionCopy[language];
  const slides = buildSlides(language);

  const sectionRef = useRef<HTMLElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const fillRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const track = trackRef.current;
    const fill = fillRef.current;
    if (!section || !track || !fill) return;

    const mm = gsap.matchMedia();

    mm.add(DESKTOP_QUERY, () => {
      const getOverflow = () => track.scrollWidth - window.innerWidth;

      const tween = gsap.to(track, {
        x: () => -getOverflow(),
        ease: "none",
      });

      const trigger = ScrollTrigger.create({
        trigger: section,
        start: "top top",
        end: () => "+=" + getOverflow(),
        pin: true,
        scrub: 1,
        invalidateOnRefresh: true,
        animation: tween,
        onUpdate: (self) => {
          gsap.set(fill, { scaleX: 0.05 + self.progress * 0.95 });
        },
      });

      // 键盘焦点进入 offscreen slide 时, 滚动到对应进度使其可见.
      const handleFocusIn = (event: FocusEvent) => {
        const target = event.target as HTMLElement | null;
        const slide = target?.closest<HTMLElement>("[data-slide-index]");
        if (!slide) return;
        const idx = Number(slide.dataset.slideIndex);
        if (Number.isNaN(idx) || slides.length < 2) return;
        const p = idx / (slides.length - 1);
        const targetScroll = trigger.start + p * (trigger.end - trigger.start);
        window.scrollTo({ top: targetScroll, behavior: "auto" });
      };

      track.addEventListener("focusin", handleFocusIn);

      return () => {
        track.removeEventListener("focusin", handleFocusIn);
      };
    });

    return () => {
      mm.revert();
    };
    // Slides count is stable across languages, so the pin is built once.
    // Language-driven width changes are handled by the refresh effect below.
  }, [slides.length]);

  // The localized copy changes each slide's width, so the horizontal-pin
  // overflow must be re-measured after a language switch. `invalidateOnRefresh`
  // on the trigger re-runs the width getters, keeping start/end/x accurate
  // against the freshly rendered track.
  useEffect(() => {
    ScrollTrigger.refresh();
  }, [language]);

  return (
    <section
      ref={sectionRef}
      id="meeting"
      data-header="dark"
      className={styles.section}
    >
      <div className={styles.heading}>
        <div>
          <p className={styles.eyebrow}>{copy.eyebrow}</p>
          <h2 className={styles.title}>{copy.title}</h2>
        </div>
        <p className={styles.lede}>{copy.lede}</p>
      </div>

      <div className={styles.progress} aria-hidden="true">
        <span ref={fillRef} className={styles.progressFill} />
      </div>

      <div className={styles.journey} id="meeting-journey">
        <div ref={trackRef} className={styles.track}>
          {slides.map((slide, i) => (
            <article
              key={slide.index}
              className={styles.slide}
              data-slide-index={i}
            >
              <div className={styles.copy}>
                <span className={styles.index}>{slide.index}</span>
                <div className={styles.copyLower}>
                  <h3 className={styles.slideTitle}>{slide.title}</h3>
                  <p className={styles.slideBody}>{slide.body}</p>
                </div>
              </div>
              <div className={styles.mediaSlot}>{slide.media}</div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

export default MeetingJourney;
