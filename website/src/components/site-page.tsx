"use client";

import { useCallback, useEffect } from "react";

import { IntroCurtain } from "@/components/intro/intro-curtain";
import { Header } from "@/components/layout/header";
import Hero from "@/components/sections/hero";
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

  const toggleLanguage = useCallback(() => {
    const current = normalizeLanguage(document.documentElement.lang);
    applyLanguage(current === "en" ? "zh" : "en");
  }, []);

  return (
    <>
      <IntroCurtain />
      <Header language={language} onLanguageToggle={toggleLanguage} />
      <main id="main-content">
        <Hero />
      </main>
    </>
  );
}

export default SitePage;
