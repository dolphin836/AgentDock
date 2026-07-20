"use client";

import { useSyncExternalStore } from "react";

export type Language = "en" | "zh";

export const LANGUAGE_STORAGE_KEY = "agentdock-language";

/**
 * Single source of truth for the site language is the `lang` attribute on the
 * document element. `SitePage` is the only writer; every section subscribes
 * through this hook, so a header toggle updates the whole page at once without
 * threading props through every component.
 */
export function toSiteLanguage(language: Language): "en" | "zh-CN" {
  return language === "zh" ? "zh-CN" : "en";
}

export function normalizeLanguage(value: string | null | undefined): Language {
  return value?.toLowerCase().startsWith("zh") ? "zh" : "en";
}

/** Reads the stored preference, falling back to the browser language. */
export function getPreferredLanguage(): Language {
  if (typeof window === "undefined") {
    return "en";
  }

  try {
    const saved = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    if (saved === "en" || saved === "zh") {
      return saved;
    }
  } catch {
    // Storage can be unavailable in private or restricted browsing contexts.
  }

  return normalizeLanguage(window.navigator.language);
}

function subscribe(onChange: () => void): () => void {
  if (typeof MutationObserver === "undefined") {
    return () => {};
  }

  const observer = new MutationObserver(onChange);
  observer.observe(document.documentElement, {
    attributeFilter: ["lang"],
    attributes: true,
  });

  return () => observer.disconnect();
}

function getSnapshot(): Language {
  return normalizeLanguage(document.documentElement.lang);
}

function getServerSnapshot(): Language {
  return "en";
}

export function useLanguage(): Language {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}
