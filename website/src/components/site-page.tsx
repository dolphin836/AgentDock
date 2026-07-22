"use client";

import { useCallback, useEffect } from "react";

import { IntroCurtain } from "@/components/intro/intro-curtain";
import { Header } from "@/components/layout/header";
import { Footer, footerContent } from "@/components/layout/footer";
import Hero from "@/components/sections/hero";
import { HomeNarrative } from "@/components/sections/home-narrative";
import { DOWNLOAD_URL } from "@/lib/release";
import {
  getPreferredLanguage,
  LANGUAGE_STORAGE_KEY,
  normalizeLanguage,
  toSiteLanguage,
  useLanguage,
  type Language,
} from "@/hooks/use-language";

const META = {
  en: {
    title: "AgentDock | Every AI agent, at a glance",
    description:
      "AgentDock keeps Claude Code, Codex, and Cursor visible in your macOS notch, with live status, approvals, usage, and one-click return.",
  },
  zh: {
    title: "AgentDock｜所有 AI 智能体，一眼掌握",
    description:
      "AgentDock 将 Claude Code、Codex 和 Cursor 的实时状态、审批、用量与一键返回集中显示在 macOS 刘海中。",
  },
} satisfies Record<Language, { title: string; description: string }>;

/**
 * Footer nav anchors resolve to sections that actually exist on the page.
 * Usage / return share the meeting journey; download uses the real DMG URL.
 */
const FOOTER_ANCHORS = {
  status: "#voice",
  approval: "#meeting",
  usage: "#meeting",
  return: "#meeting",
  integrations: "#integrations",
  privacy: "#privacy",
  download: DOWNLOAD_URL,
} as const;

/**
 * Applies the language to the document (the single source of truth every
 * section subscribes to via `useLanguage`). This only writes to external
 * systems — the DOM, the document metadata, and localStorage — so it never
 * triggers a synchronous React state update.
 */
function applyLanguage(language: Language): void {
  const meta = META[language];
  document.documentElement.lang = toSiteLanguage(language);
  document.title = meta.title;

  let description = document.querySelector<HTMLMetaElement>(
    'meta[name="description"]',
  );
  if (description === null) {
    description = document.createElement("meta");
    description.name = "description";
    document.head.append(description);
  }
  description.content = meta.description;

  try {
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
  } catch {
    // Language still applies when storage is unavailable.
  }
}

function refreshScrollTriggerSoon(): void {
  void (async () => {
    try {
      const { ScrollTrigger } = await import("gsap/ScrollTrigger");
      // Two frames so a removed intro overlay and reveal styles have settled.
      requestAnimationFrame(() =>
        requestAnimationFrame(() => ScrollTrigger.refresh()),
      );
    } catch {
      // GSAP is optional; static layout remains usable without a refresh.
    }
  })();
}

export function SitePage() {
  // The document `lang` attribute is the single source of truth; this hook
  // re-renders the whole tree whenever it changes so every section stays in
  // sync with the header toggle.
  const language = useLanguage();

  // Resolve the stored / browser preference after mount. Writing the DOM lang
  // (rather than React state) keeps SSR output deterministic and avoids a
  // synchronous setState inside the effect.
  useEffect(() => {
    applyLanguage(getPreferredLanguage());
  }, []);

  // Global reveal observer: reveals every [data-reveal] element once it scrolls
  // into view. CSS only hides these under `.motion-ready` (added by the intro
  // curtain after JS confirms), so reduced-motion / no-JS visitors see them
  // immediately. Centralising this avoids each section shipping its own
  // observer and keeps GSAP scroll triggers from fighting over the same nodes.
  useEffect(() => {
    if (typeof IntersectionObserver === "undefined") {
      return;
    }

    const targets = Array.from(
      document.querySelectorAll<HTMLElement>("[data-reveal]"),
    );
    if (targets.length === 0) {
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        }
      },
      { threshold: 0.15, rootMargin: "0px 0px -8% 0px" },
    );

    targets.forEach((target) => observer.observe(target));
    return () => observer.disconnect();
  }, []);

  const toggleLanguage = useCallback(() => {
    const current = normalizeLanguage(document.documentElement.lang);
    applyLanguage(current === "en" ? "zh" : "en");
  }, []);

  const handleIntroComplete = useCallback(() => {
    refreshScrollTriggerSoon();
  }, []);

  return (
    <>
      <IntroCurtain onComplete={handleIntroComplete} />
      <Header language={language} onLanguageToggle={toggleLanguage} />
      <main id="main-content">
        <Hero />
        <HomeNarrative />
      </main>
      <Footer
        anchors={FOOTER_ANCHORS}
        content={language === "zh" ? footerContent.zh : footerContent.en}
      />
    </>
  );
}

export default SitePage;
