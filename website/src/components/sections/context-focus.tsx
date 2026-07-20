"use client";

import dynamic from "next/dynamic";
import { useEffect, useRef } from "react";

import { useLanguage } from "@/hooks/use-language";

import styles from "./context-focus.module.css";

const ContextFocusCanvas = dynamic(
  () => import("./context-focus-canvas"),
  { ssr: false },
);

const copyByLanguage = {
  en: {
    eyebrow: "02 / ONE ENTRANCE",
    titleLead: "Three kinds of agent.",
    titleTail: "One place to look.",
    description:
      "Claude Code, Codex, and Cursor each work differently. AgentDock brings their visible state to one entrance in the notch, so your attention has one destination instead of many.",
  },
  zh: {
    eyebrow: "02 / 一个入口",
    titleLead: "三类 Agent，",
    titleTail: "只看一处。",
    description:
      "Claude Code、Codex 与 Cursor 各有不同的工作方式。AgentDock 把可见状态汇入刘海里的同一个入口，让你的注意力只有一个去处，而不是许多个。",
  },
} as const;

export default function ContextFocus() {
  const language = useLanguage();
  const copy = copyByLanguage[language];
  const sectionRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const sectionEl = sectionRef.current;
    if (!sectionEl) {
      return;
    }

    const revealEls = Array.from(
      sectionEl.querySelectorAll<HTMLElement>("[data-focus-reveal]"),
    );

    // Arm the pre-reveal state only now that client JS is confirmed running,
    // so a JS failure (or no JS) leaves the copy fully visible by default.
    sectionEl.setAttribute("data-focus-armed", "true");

    const reduceMotion =
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (reduceMotion || revealEls.length === 0) {
      // Reduced motion falls straight to the final frame via CSS.
      return;
    }

    let cancelled = false;
    let ctx: { revert: () => void } | undefined;

    void (async () => {
      try {
        const [{ gsap }, { ScrollTrigger }] = await Promise.all([
          import("gsap"),
          import("gsap/ScrollTrigger"),
        ]);
        if (cancelled) {
          return;
        }
        gsap.registerPlugin(ScrollTrigger);
        ctx = gsap.context(() => {
          gsap.to(revealEls, {
            y: 0,
            opacity: 1,
            duration: 0.9,
            ease: "power3.out",
            stagger: 0.12,
            clearProps: "willChange",
            scrollTrigger: {
              trigger: sectionEl,
              start: "top 75%",
              once: true,
            },
          });
        }, sectionEl);
      } catch {
        // GSAP unavailable — drop the armed state so copy stays visible.
        if (!cancelled) {
          sectionEl.removeAttribute("data-focus-armed");
        }
      }
    })();

    return () => {
      cancelled = true;
      ctx?.revert();
    };
  }, []);

  return (
    <section
      ref={sectionRef}
      id="context-focus"
      className={styles.section}
      data-header="light"
      aria-labelledby="context-focus-title"
    >
      <div className={styles.scene} aria-hidden="true">
        <ContextFocusCanvas
          id="context-focus-canvas"
          className={styles.canvas}
        />
      </div>
      <div className={styles.vignette} aria-hidden="true" />
      <div className={styles.copy}>
        <div className={styles.headingGroup}>
          <p className={styles.eyebrow} data-focus-reveal>
            {copy.eyebrow}
          </p>
          <h2
            className={styles.title}
            id="context-focus-title"
            data-focus-reveal
          >
            <span className={styles.titleLine}>
              {copy.titleLead}
              <span className={styles.nowrap}>{copy.titleTail}</span>
            </span>
          </h2>
        </div>
        <p className={styles.description} data-focus-reveal>
          {copy.description}
        </p>
      </div>
    </section>
  );
}
