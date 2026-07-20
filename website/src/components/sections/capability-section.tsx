"use client";

import { type ReactNode, useEffect, useRef } from "react";

import { useLanguage } from "@/hooks/use-language";

import styles from "./capability-section.module.css";

const reducedMotionQuery = "(prefers-reduced-motion: reduce)";

const headingCopy = {
  en: {
    eyebrow: "01 / FOCUS",
    title: "Know what needs you, without checking every window.",
    description:
      "One quiet surface for the moments that matter across your local Claude Code, Codex, and Cursor work.",
  },
  zh: {
    eyebrow: "01 / 专注",
    title: "不用切遍每个窗口，也知道哪件事需要你。",
    description:
      "为本地 Claude Code、Codex 与 Cursor 工作中真正重要的时刻，留出一个安静的界面。",
  },
} as const;

type CapabilitySectionProps = {
  children: ReactNode;
};

export function CapabilitySection({ children }: CapabilitySectionProps) {
  const language = useLanguage();
  const copy = headingCopy[language];
  const sectionRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const revealBand = section?.querySelector<HTMLElement>("[data-reveal-band]");

    if (!section || !revealBand) {
      return;
    }

    const mediaQuery = window.matchMedia(reducedMotionQuery);
    let cancelled = false;
    let gsapContext: { revert: () => void } | undefined;

    if (mediaQuery.matches) {
      revealBand.style.clipPath = "inset(0)";
      return;
    }

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
        gsapContext = gsap.context(() => {
          gsap.fromTo(
            revealBand,
            { clipPath: "inset(0 100% 0 0)" },
            {
              clipPath: "inset(0 0% 0 0)",
              ease: "none",
              scrollTrigger: {
                trigger: revealBand,
                start: "top 85%",
                end: "top 30%",
                scrub: 1,
              },
            },
          );
        }, section);
      } catch {
        revealBand.style.clipPath = "inset(0)";
      }
    })();

    return () => {
      cancelled = true;
      gsapContext?.revert();
    };
  }, []);

  return (
    <section
      ref={sectionRef}
      id="product"
      className={styles.section}
      data-header="light"
      aria-labelledby="product-heading"
    >
      <div className={styles.inner}>
        <div className={styles.heading} data-reveal>
          <p className={styles.eyebrow}>{copy.eyebrow}</p>
          <h2 id="product-heading">{copy.title}</h2>
          <p className={styles.description}>{copy.description}</p>
        </div>

        <div className={styles.panels} data-reveal-band>
          {children}
        </div>
      </div>
    </section>
  );
}

export default CapabilitySection;
