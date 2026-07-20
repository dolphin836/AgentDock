"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

import { BrandIcon } from "@/components/icons";
import { DOWNLOAD_FILENAME } from "@/lib/release";

import styles from "./header-shell.module.css";

export type HeaderLanguage = "en" | "zh-CN";

export type HeaderShellProps = {
  children: ReactNode;
  downloadUrl: string;
  menuOpen: boolean;
  onMenuToggle: () => void;
  language: HeaderLanguage;
  onLanguageToggle: () => void;
};

function getHeaderTone(): "dark" | "light" {
  const probe = document.elementsFromPoint(
    window.innerWidth / 2,
    Math.min(window.innerHeight - 1, 80),
  );

  for (const element of probe) {
    const section = element.closest<HTMLElement>("[data-header]");
    const tone = section?.dataset.header;
    if (tone === "dark" || tone === "light") {
      return tone;
    }
  }

  return "light";
}

export function HeaderShell({
  children,
  downloadUrl,
  menuOpen,
  onMenuToggle,
  language,
  onLanguageToggle,
}: HeaderShellProps) {
  const lastScrollY = useRef(0);
  const [isScrolled, setIsScrolled] = useState(false);
  const [isHidden, setIsHidden] = useState(false);
  const [tone, setTone] = useState<"dark" | "light">("light");

  useEffect(() => {
    let frame = 0;

    const updateHeader = () => {
      frame = 0;
      const scrollY = window.scrollY;
      const delta = scrollY - lastScrollY.current;
      const isCompact = scrollY > window.innerHeight * 0.22;

      setIsScrolled(isCompact);
      setIsHidden((current) => {
        if (scrollY <= window.innerHeight) {
          lastScrollY.current = scrollY;
          return false;
        }
        if (Math.abs(delta) <= 12) {
          return current;
        }
        lastScrollY.current = scrollY;
        return delta > 0;
      });
      setTone(getHeaderTone());
    };

    const requestUpdate = () => {
      if (frame === 0) {
        frame = window.requestAnimationFrame(updateHeader);
      }
    };

    updateHeader();
    window.addEventListener("scroll", requestUpdate, { passive: true });
    window.addEventListener("resize", requestUpdate);

    return () => {
      window.removeEventListener("scroll", requestUpdate);
      window.removeEventListener("resize", requestUpdate);
      if (frame !== 0) {
        window.cancelAnimationFrame(frame);
      }
    };
  }, []);

  return (
    <header
      className={styles.header}
      data-hidden={isHidden && !menuOpen ? "true" : undefined}
      data-scrolled={isScrolled ? "true" : undefined}
      data-tone={tone}
      data-menu-open={menuOpen ? "true" : undefined}
    >
      <div className={styles.inner}>
        <a aria-label="AgentDock home" className={styles.brand} href="#top">
          <BrandIcon alt="" className={styles.appIcon} />
          <span>AgentDock</span>
        </a>

        <div className={styles.navigation}>{children}</div>

        <div className={styles.actions}>
          <button
            aria-label={
              language === "en" ? "Switch to Chinese" : "Switch to English"
            }
            className={styles.language}
            onClick={onLanguageToggle}
            type="button"
          >
            {language === "en" ? "中文" : "EN"}
          </button>
          <a
            className={styles.download}
            download={DOWNLOAD_FILENAME}
            href={downloadUrl}
          >
            {language === "en" ? "Download" : "下载"}
          </a>
          <button
            aria-controls="site-menu"
            aria-expanded={menuOpen}
            aria-label={menuOpen ? "Close navigation menu" : "Open navigation menu"}
            className={styles.menuToggle}
            data-mobile-menu-button
            onClick={onMenuToggle}
            type="button"
          >
            <span />
            <span />
            <span />
            <span />
          </button>
        </div>
      </div>
    </header>
  );
}
