"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";

import styles from "./intro-curtain.module.css";

const TOTAL_DURATION_MS = 1050;
const COMPLETION_DURATION_MS = 180;
const EXIT_DURATION_MS = 900;
const MAX_WAIT_MS = 3000;
const MOBILE_QUERY = "(max-width: 680px)";
const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

export type IntroCurtainProps = {
  /** Fired once client motion is enabled (curtain done, skipped, or reduced). */
  onComplete?: () => void;
};

export function IntroCurtain({ onComplete }: IntroCurtainProps) {
  const [progress, setProgress] = useState(0);
  const [isExiting, setIsExiting] = useState(false);
  const [isMounted, setIsMounted] = useState(true);
  const progressRef = useRef(0);
  const onCompleteRef = useRef(onComplete);

  useEffect(() => {
    onCompleteRef.current = onComplete;
  }, [onComplete]);

  useEffect(() => {
    const enableMotion = (): void => {
      document.documentElement.classList.add("motion-ready");
      onCompleteRef.current?.();
    };

    const mobileQuery = window.matchMedia(MOBILE_QUERY);
    const reducedMotionQuery = window.matchMedia(REDUCED_MOTION_QUERY);

    if (mobileQuery.matches || reducedMotionQuery.matches) {
      enableMotion();
      const skipTimer = setTimeout(() => setIsMounted(false), 0);
      return () => clearTimeout(skipTimer);
    }

    let animationFrame = 0;
    let removalTimer: ReturnType<typeof setTimeout> | undefined;
    let readyTimer: ReturnType<typeof setTimeout> | undefined;
    let isComplete = false;
    let isCompleting = false;
    const startedAt = performance.now();
    const earliestCompletionAt =
      startedAt + TOTAL_DURATION_MS - COMPLETION_DURATION_MS;

    const finish = () => {
      if (isComplete) {
        return;
      }

      isComplete = true;
      cancelAnimationFrame(animationFrame);
      clearTimeout(fallbackTimer);
      clearTimeout(readyTimer);
      setProgress(100);
      progressRef.current = 100;
      setIsExiting(true);

      removalTimer = setTimeout(() => {
        setIsMounted(false);
        enableMotion();
      }, EXIT_DURATION_MS);
    };

    const completeProgress = () => {
      if (isComplete || isCompleting) {
        return;
      }

      isCompleting = true;
      cancelAnimationFrame(animationFrame);
      const completionStartedAt = performance.now();
      const completionStartedFrom = progressRef.current;

      const animateCompletion = (now: number) => {
        const completionRatio = Math.min(
          (now - completionStartedAt) / COMPLETION_DURATION_MS,
          1,
        );
        const nextProgress =
          completionStartedFrom +
          (100 - completionStartedFrom) * completionRatio;

        progressRef.current = nextProgress;
        setProgress(nextProgress);

        if (completionRatio < 1) {
          animationFrame = requestAnimationFrame(animateCompletion);
          return;
        }

        finish();
      };

      animationFrame = requestAnimationFrame(animateCompletion);
    };

    const handleResourcesReady = () => {
      const delay = Math.max(earliestCompletionAt - performance.now(), 0);
      readyTimer = setTimeout(completeProgress, delay);
    };

    const animateInitialProgress = (now: number) => {
      const elapsed = now - startedAt;
      const nextProgress = Math.min(
        (elapsed / (TOTAL_DURATION_MS - COMPLETION_DURATION_MS)) * 90,
        90,
      );

      progressRef.current = nextProgress;
      setProgress(nextProgress);

      if (!isComplete) {
        animationFrame = requestAnimationFrame(animateInitialProgress);
      }
    };

    animationFrame = requestAnimationFrame(animateInitialProgress);

    if (document.readyState === "complete") {
      handleResourcesReady();
    } else {
      window.addEventListener("load", handleResourcesReady, { once: true });
    }

    const fallbackTimer = setTimeout(() => {
      cancelAnimationFrame(animationFrame);
      completeProgress();
    }, MAX_WAIT_MS - COMPLETION_DURATION_MS);

    return () => {
      isComplete = true;
      window.removeEventListener("load", handleResourcesReady);
      cancelAnimationFrame(animationFrame);
      clearTimeout(removalTimer);
      clearTimeout(fallbackTimer);
      clearTimeout(readyTimer);
    };
  }, []);

  if (!isMounted) {
    return null;
  }

  return (
    <div
      aria-hidden="true"
      className={`${styles.curtain} ${isExiting ? styles.exiting : ""}`}
    >
      <div className={styles.brand}>
        <Image
          alt=""
          className={styles.icon}
          height={48}
          priority
          src="/app-icon.png"
          width={48}
        />
        <span>AgentDock</span>
      </div>

      <span className={styles.progress}>
        {Math.round(progress).toString().padStart(3, "0")}%
      </span>
    </div>
  );
}

export default IntroCurtain;
