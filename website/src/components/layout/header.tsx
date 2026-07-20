"use client";

// [skill: go-team-standards · dev-dna · code-review v2] 装配双语响应式页头
import { useCallback, useEffect, useMemo, useState } from "react";

import type { NavigationItem } from "@/types/site";
import { toSiteLanguage, type Language } from "@/hooks/use-language";
import { DOWNLOAD_URL } from "@/lib/release";

import { DesktopNav } from "./desktop-nav";
import { HeaderShell } from "./header-shell";
import { MobileMenu } from "./mobile-menu";

type HeaderCopy = {
  skipLink: string;
  navigationLabel: string;
  download: string;
  navigation: {
    status: string;
    approval: string;
    integrations: string;
    privacy: string;
  };
};

const headerCopy = {
  en: {
    skipLink: "Skip to main content",
    navigationLabel: "Primary navigation",
    download: "Download AgentDock",
    navigation: {
      status: "Status",
      approval: "Approval",
      integrations: "Integrations",
      privacy: "Privacy",
    },
  },
  zh: {
    skipLink: "跳到主要内容",
    navigationLabel: "主要导航",
    download: "下载 AgentDock",
    navigation: {
      status: "状态",
      approval: "审批",
      integrations: "集成",
      privacy: "隐私",
    },
  },
} satisfies Record<Language, HeaderCopy>;

export type HeaderProps = {
  language: Language;
  onLanguageToggle: () => void;
};

function getSectionHref(section: Element, hrefs: readonly string[]) {
  return hrefs.find((href) => {
    const target = document.getElementById(href.slice(1));
    return target === section || (target !== null && section.contains(target));
  });
}

export function Header({ language, onLanguageToggle }: HeaderProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [activeHref, setActiveHref] = useState("#voice");
  const copy = headerCopy[language];

  const navItems = useMemo(
    () => [
      { href: "#voice", label: copy.navigation.status },
      { href: "#meeting", label: copy.navigation.approval },
      { href: "#integrations", label: copy.navigation.integrations },
      { href: "#privacy", label: copy.navigation.privacy },
    ],
    [copy],
  );
  const menuItems = useMemo<ReadonlyArray<NavigationItem>>(
    () => [
      {
        id: "status",
        href: "#voice",
        label: {
          en: headerCopy.en.navigation.status,
          "zh-CN": headerCopy.zh.navigation.status,
        },
      },
      {
        id: "approval",
        href: "#meeting",
        label: {
          en: headerCopy.en.navigation.approval,
          "zh-CN": headerCopy.zh.navigation.approval,
        },
      },
      {
        id: "integrations",
        href: "#integrations",
        label: {
          en: headerCopy.en.navigation.integrations,
          "zh-CN": headerCopy.zh.navigation.integrations,
        },
      },
      {
        id: "privacy",
        href: "#privacy",
        label: {
          en: headerCopy.en.navigation.privacy,
          "zh-CN": headerCopy.zh.navigation.privacy,
        },
      },
      {
        id: "download",
        href: DOWNLOAD_URL,
        isExternal: true,
        label: { en: headerCopy.en.download, "zh-CN": headerCopy.zh.download },
      },
    ],
    [],
  );
  const siteLanguage = toSiteLanguage(language);

  useEffect(() => {
    const hrefs = navItems.map(({ href }) => href);
    const sections = Array.from(
      document.querySelectorAll<HTMLElement>("[data-header]"),
    ).filter((section) => getSectionHref(section, hrefs) !== undefined);

    if (sections.length === 0) {
      return;
    }

    const visibleSections = new Map<Element, IntersectionObserverEntry>();
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            visibleSections.set(entry.target, entry);
          } else {
            visibleSections.delete(entry.target);
          }
        }

        const currentSection = [...visibleSections.values()].sort(
          (left, right) =>
            Math.abs(left.boundingClientRect.top) -
            Math.abs(right.boundingClientRect.top),
        )[0]?.target;
        const currentHref =
          currentSection && getSectionHref(currentSection, hrefs);

        if (currentHref !== undefined) {
          setActiveHref(currentHref);
        }
      },
      { rootMargin: "-16% 0px -68% 0px", threshold: [0, 0.01] },
    );

    sections.forEach((section) => observer.observe(section));
    return () => observer.disconnect();
  }, [navItems]);

  const closeMenu = useCallback(() => setMenuOpen(false), []);
  const toggleMenu = useCallback(() => setMenuOpen((open) => !open), []);

  return (
    <>
      <a className="skip-link" href="#main-content">
        {copy.skipLink}
      </a>
      <HeaderShell
        downloadUrl={DOWNLOAD_URL}
        language={siteLanguage}
        menuOpen={menuOpen}
        onLanguageToggle={onLanguageToggle}
        onMenuToggle={toggleMenu}
      >
        <DesktopNav
          activeHref={activeHref}
          ariaLabel={copy.navigationLabel}
          items={navItems}
        />
      </HeaderShell>
      <MobileMenu
        items={menuItems}
        language={siteLanguage}
        onClose={closeMenu}
        open={menuOpen}
      />
    </>
  );
}

export default Header;
