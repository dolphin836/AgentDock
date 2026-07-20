"use client";

import { useEffect, useRef } from "react";

import { useLanguage } from "@/hooks/use-language";

import { ContextHotwordHistoryGrid } from "./context-hotword-history-grid";
import { ContextIntegrationsGrid } from "./context-integrations-grid";
import styles from "./context-world.module.css";

const lineScales = [1, 0.91, 0.782, 0.654, 0.526] as const;
const reducedMotionQuery = "(prefers-reduced-motion: reduce)";

const visionCopy = {
  en: {
    eyebrow: "AGENTDOCK VISION",
    title: "Let every agent's state keep working for you",
  },
  zh: {
    eyebrow: "AgentDock 愿景",
    title: "让每个 Agent 的状态，继续为你工作",
  },
} as const;

export function ContextWorld() {
  const language = useLanguage();
  const vision = visionCopy[language];
  const sectionRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const sectionEl = sectionRef.current;
    if (!sectionEl) {
      return;
    }

    const mediaQuery = window.matchMedia(reducedMotionQuery);
    const revealEls = Array.from(
      sectionEl.querySelectorAll<HTMLElement>("[data-reveal]"),
    );
    let revealObserver: IntersectionObserver | undefined;
    let gsapContext: { revert: () => void } | undefined;
    let cancelled = false;
    let motionRun = 0;

    const revealContent = () => {
      revealEls.forEach((element) => element.classList.add("is-visible"));
    };

    const startMotion = () => {
      const currentRun = ++motionRun;
      if (cancelled || mediaQuery.matches) {
        revealContent();
        return;
      }

      if ("IntersectionObserver" in window && revealEls.length > 0) {
        sectionEl.dataset.motionReady = "true";
        revealObserver = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (!entry.isIntersecting) {
                return;
              }

              entry.target.classList.add("is-visible");
              revealObserver?.unobserve(entry.target);
            });
          },
          { threshold: 0.15 },
        );
        revealEls.forEach((element) => revealObserver?.observe(element));
      }

      void (async () => {
        try {
          const [{ gsap }, { ScrollTrigger }] = await Promise.all([
            import("gsap"),
            import("gsap/ScrollTrigger"),
          ]);
          if (cancelled || currentRun !== motionRun || mediaQuery.matches) {
            return;
          }

          gsap.registerPlugin(ScrollTrigger);
          const lines = Array.from(
            sectionEl.querySelectorAll<HTMLElement>(`[data-context-line]`),
          );
          gsapContext = gsap.context(() => {
            lines.forEach((line, index) => {
              gsap.to(line, {
                scaleY: lineScales[index] ?? 0.2,
                ease: "none",
                scrollTrigger: {
                  trigger: sectionEl,
                  start: "top bottom",
                  end: "bottom top",
                  scrub: true,
                },
              });
            });
          }, sectionEl);
        } catch {
          // Decorative motion is optional; the static backdrop remains usable.
        }
      })();
    };

    const stopMotion = () => {
      motionRun += 1;
      sectionEl.removeAttribute("data-motion-ready");
      revealObserver?.disconnect();
      revealObserver = undefined;
      gsapContext?.revert();
      gsapContext = undefined;
      revealContent();
    };

    const handleMotionPreferenceChange = () => {
      stopMotion();
      startMotion();
    };

    startMotion();
    mediaQuery.addEventListener("change", handleMotionPreferenceChange);

    return () => {
      cancelled = true;
      mediaQuery.removeEventListener("change", handleMotionPreferenceChange);
      stopMotion();
    };
  }, []);

  return (
    <section
      ref={sectionRef}
      id="context"
      className={styles.section}
      data-header="dark"
      aria-labelledby="context-vision"
    >
      <div className={styles.backdrop} aria-hidden="true">
        {lineScales.map((_, index) => (
          <span data-context-line key={index} />
        ))}
      </div>

      <div id="personalization" className={styles.chapter}>
        <ContextHotwordHistoryGrid />
      </div>
      <div id="agent" className={`${styles.chapter} ${styles.reverse}`}>
        <ContextIntegrationsGrid />
      </div>

      <div className={styles.vision} data-reveal>
        <p className={styles.eyebrow}>{vision.eyebrow}</p>
        <h3 id="context-vision">{vision.title}</h3>
      </div>
    </section>
  );
}

export default ContextWorld;
