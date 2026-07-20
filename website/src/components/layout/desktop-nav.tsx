// [skill: code-review v2] 已自检 · P0 修 0 条 / P1 修 0 条 / 通过 14 项
// [skill: dev-dna] 按用户偏好保持受控 API、严格类型与最小改动范围
"use client";

import {
  type CSSProperties,
  type ReactNode,
  useCallback,
  useLayoutEffect,
  useRef,
} from "react";

import styles from "./desktop-nav.module.css";

export type DesktopNavItem = {
  href: string;
  label: ReactNode;
};

export type DesktopNavProps = {
  activeHref: string;
  ariaLabel?: string;
  className?: string;
  items: ReadonlyArray<DesktopNavItem>;
};

type IndicatorStyle = CSSProperties & {
  "--indicator-width": string;
  "--indicator-x": string;
};

const hiddenIndicatorStyle: IndicatorStyle = {
  "--indicator-width": "0px",
  "--indicator-x": "0px",
};

export function DesktopNav({
  activeHref,
  ariaLabel = "Primary navigation",
  className,
  items,
}: DesktopNavProps) {
  const navRef = useRef<HTMLElement>(null);
  const indicatorRef = useRef<HTMLSpanElement>(null);
  const linkRefs = useRef<Array<HTMLAnchorElement | null>>([]);
  const hoveredLinkRef = useRef<HTMLAnchorElement | null>(null);
  const focusedLinkRef = useRef<HTMLAnchorElement | null>(null);

  const getActiveLink = useCallback(() => {
    const activeIndex = items.findIndex((item) => item.href === activeHref);
    return activeIndex >= 0 ? linkRefs.current[activeIndex] : null;
  }, [activeHref, items]);

  const measureLink = useCallback((link: HTMLAnchorElement | null) => {
    const nav = navRef.current;
    const indicator = indicatorRef.current;

    if (!nav || !indicator || !link) {
      if (indicator) {
        indicator.style.opacity = "0";
      }
      return;
    }

    const navRect = nav.getBoundingClientRect();
    const linkRect = link.getBoundingClientRect();

    indicator.style.setProperty("--indicator-width", `${linkRect.width}px`);
    indicator.style.setProperty(
      "--indicator-x",
      `${linkRect.left - navRect.left}px`,
    );
    indicator.style.opacity = "1";
  }, []);

  const syncIndicator = useCallback(() => {
    measureLink(
      focusedLinkRef.current ??
        hoveredLinkRef.current ??
        getActiveLink(),
    );
  }, [getActiveLink, measureLink]);

  useLayoutEffect(() => {
    linkRefs.current.length = items.length;
    syncIndicator();

    const nav = navRef.current;
    if (!nav) {
      return;
    }

    const resizeObserver = new ResizeObserver(syncIndicator);
    resizeObserver.observe(nav);
    linkRefs.current.forEach((link) => {
      if (link) {
        resizeObserver.observe(link);
      }
    });

    const languageObserver = new MutationObserver(syncIndicator);
    languageObserver.observe(document.documentElement, {
      attributeFilter: ["lang"],
      attributes: true,
    });

    const fontSet = document.fonts;
    let cancelled = false;
    const syncAfterFontsLoad = () => {
      if (!cancelled) {
        syncIndicator();
      }
    };

    void fontSet.ready.then(syncAfterFontsLoad);
    fontSet.addEventListener("loadingdone", syncAfterFontsLoad);

    return () => {
      cancelled = true;
      resizeObserver.disconnect();
      languageObserver.disconnect();
      fontSet.removeEventListener("loadingdone", syncAfterFontsLoad);
    };
  }, [items, syncIndicator]);

  const navClassName = [styles.nav, className].filter(Boolean).join(" ");

  return (
    <nav
      aria-label={ariaLabel}
      className={navClassName}
      ref={navRef}
    >
      {items.map((item, index) => (
        <a
          aria-current={item.href === activeHref ? "page" : undefined}
          className={styles.link}
          href={item.href}
          key={`${item.href}-${index}`}
          onBlur={() => {
            focusedLinkRef.current = null;
            measureLink(hoveredLinkRef.current ?? getActiveLink());
          }}
          onFocus={(event) => {
            focusedLinkRef.current = event.currentTarget;
            measureLink(event.currentTarget);
          }}
          onPointerEnter={(event) => {
            hoveredLinkRef.current = event.currentTarget;
            measureLink(event.currentTarget);
          }}
          onPointerLeave={() => {
            hoveredLinkRef.current = null;
            measureLink(focusedLinkRef.current ?? getActiveLink());
          }}
          ref={(link) => {
            linkRefs.current[index] = link;
          }}
        >
          {item.label}
        </a>
      ))}

      <span
        aria-hidden="true"
        className={styles.indicator}
        ref={indicatorRef}
        style={hiddenIndicatorStyle}
      />
    </nav>
  );
}
