"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { ReactElement, SVGProps } from "react";

import type { Language } from "@/hooks/use-language";

import type { VoiceStageState } from "./voice-section";
import styles from "./voice-result-stage.module.css";

const STAGE_LABELS = {
  en: { before: "Now", after: "AgentDock output" },
  zh: { before: "现状", after: "AgentDock 输出" },
} as const;

const CHAR_INTERVAL_MS = 34;

export interface VoiceResultStageProps {
  readonly state: VoiceStageState;
  readonly language: Language;
  readonly reducedMotion: boolean;
}

// `status` arrives as a single "pending → complete" string; split it so the
// stage can show the pending phase while typing and the complete phase after.
function splitStatus(status: string): { pending: string; complete: string } {
  const parts = status.split("→").map((part) => part.trim());

  if (parts.length >= 2 && parts[1]) {
    return { pending: parts[0], complete: parts[1] };
  }

  return { pending: status.trim(), complete: status.trim() };
}

type StageIconKey =
  | "live-status"
  | "approval"
  | "waiting"
  | "usage"
  | "return";

function iconKeyFromId(iconId: string): StageIconKey {
  const key = iconId.replace("#voice-icon-", "");

  switch (key) {
    case "live-status":
    case "approval":
    case "waiting":
    case "usage":
    case "return":
      return key;
    default:
      return "live-status";
  }
}

function IconFrame({ children, ...props }: SVGProps<SVGSVGElement>) {
  return (
    <svg
      aria-hidden="true"
      fill="none"
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      {children}
    </svg>
  );
}

// Original AgentDock status glyphs — authored for this stage, not derived from
// any third-party icon set.
const STAGE_ICONS: Record<StageIconKey, (props: SVGProps<SVGSVGElement>) => ReactElement> = {
  "live-status": (props) => (
    <IconFrame {...props}>
      <circle cx="12" cy="12" fill="currentColor" r="2.4" />
      <path
        d="M7.3 7.3a6.6 6.6 0 0 0 0 9.4M16.7 7.3a6.6 6.6 0 0 1 0 9.4"
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth="1.7"
      />
    </IconFrame>
  ),
  approval: (props) => (
    <IconFrame {...props}>
      <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="1.7" />
      <path
        d="m8.4 12.2 2.4 2.4 4.8-5"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.7"
      />
    </IconFrame>
  ),
  waiting: (props) => (
    <IconFrame {...props}>
      <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="1.7" />
      <path
        d="M12 8v4l3 2"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.7"
      />
    </IconFrame>
  ),
  usage: (props) => (
    <IconFrame {...props}>
      <path d="M5 19h14" stroke="currentColor" strokeLinecap="round" strokeWidth="1.7" />
      <path
        d="M8 19v-5M12 19v-9M16 19v-6"
        stroke="currentColor"
        strokeLinecap="round"
        strokeWidth="2"
      />
    </IconFrame>
  ),
  return: (props) => (
    <IconFrame {...props}>
      <path
        d="M9 7 6 10l3 3"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.7"
      />
      <path
        d="M6 10h8a4 4 0 0 1 4 4v3"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.7"
      />
    </IconFrame>
  ),
};

function StageIcon({ iconId }: { iconId: string }) {
  const render = STAGE_ICONS[iconKeyFromId(iconId)];
  return render({});
}

export function VoiceResultStage({
  state,
  language,
  reducedMotion,
}: VoiceResultStageProps) {
  const labels = STAGE_LABELS[language];
  // Split by Unicode code points so CJK characters and emoji are never cut
  // mid-sequence the way a UTF-16 code-unit slice would.
  const glyphs = useMemo(() => Array.from(state.after), [state.after]);

  // reduced motion renders the full text immediately with no reveal.
  const [visibleCount, setVisibleCount] = useState(
    reducedMotion ? glyphs.length : 0,
  );

  // Reset the reveal during render whenever the active state or the motion
  // preference changes — the sanctioned way to derive state from props without
  // a synchronous setState inside an effect.
  const revealKey = `${state.id}|${reducedMotion}`;
  const [trackedKey, setTrackedKey] = useState(revealKey);
  if (trackedKey !== revealKey) {
    setTrackedKey(revealKey);
    setVisibleCount(reducedMotion ? glyphs.length : 0);
  }

  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (reducedMotion || glyphs.length === 0) {
      return;
    }

    let start: number | null = null;

    const tick = (timestamp: number) => {
      if (start === null) {
        start = timestamp;
      }

      const elapsed = timestamp - start;
      const count = Math.min(
        glyphs.length,
        Math.floor(elapsed / CHAR_INTERVAL_MS) + 1,
      );

      // setState inside the rAF callback advances the reveal one glyph at a
      // time; the callback runs asynchronously so no cascading render occurs.
      setVisibleCount(count);

      if (count >= glyphs.length) {
        rafRef.current = null;
        return;
      }

      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);

    // Cancel the in-flight animation on unmount or when the active state
    // changes, so glyphs from a previous state never bleed into the new one.
    return () => {
      if (rafRef.current !== null) {
        cancelAnimationFrame(rafRef.current);
        rafRef.current = null;
      }
    };
  }, [revealKey, glyphs, reducedMotion]);

  const clampedCount = Math.min(visibleCount, glyphs.length);
  const output = glyphs.slice(0, clampedCount).join("");
  const isComplete = clampedCount >= glyphs.length;
  const isTyping = !reducedMotion && !isComplete && glyphs.length > 0;
  // Announce the finished text once, rather than on every character.
  const announcement = isComplete ? state.after : "";

  const { pending, complete } = splitStatus(state.status);
  const statusText = isComplete ? complete : pending;

  return (
    <div
      id="voice-result-stage"
      role="tabpanel"
      aria-labelledby={`voice-tab-${state.id}`}
      className={styles.stage}
    >
      <div className={styles.appBar}>
        <div className={styles.appIdentity}>
          <span className={styles.appIcon}>
            <StageIcon iconId={state.iconId} />
          </span>
          <span data-voice-app-name>{state.appName}</span>
        </div>
        <div className={styles.stageStatus}>
          <span className={styles.statusDot} data-done={isComplete} aria-hidden="true" />
          <span data-voice-status aria-live="polite">
            {statusText}
          </span>
        </div>
      </div>

      <div className={styles.editor}>
        <div className={styles.before}>
          <span className={styles.proofLabel}>{labels.before}</span>
          <p>{state.before}</p>
        </div>

        <div className={styles.after}>
          <div className={styles.meta}>
            <span className={styles.proofLabel}>{labels.after}</span>
            <span className={styles.metaContext} data-voice-app-context>
              {state.context}
            </span>
          </div>
          <div className={styles.output} data-voice-output>
            {output}
            <span className={styles.caret} data-typing={isTyping} aria-hidden="true" />
          </div>
        </div>

        <div className={styles.captureLayer} aria-hidden="true" />
      </div>

      <span className={styles.srOnly} aria-live="polite" role="status">
        {announcement}
      </span>
    </div>
  );
}
