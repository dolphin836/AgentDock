"use client";

// [skill: code-review v2] 已自检 · P0 修 0 条 / P1 修 0 条 / 通过焦点与锁定检查
import {
  useEffect,
  useId,
  useRef,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";

import type { NavigationItem, SiteLanguage } from "@/types/site";

import styles from "./mobile-menu.module.css";

const menuButtonSelector =
  "[data-mobile-menu-button], [data-menu-button], #menu-button";
const focusableSelector =
  'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])';

export type MobileMenuProps = {
  open: boolean;
  items: ReadonlyArray<NavigationItem>;
  onClose: () => void;
  language: SiteLanguage;
};

function getFocusableElements(container: HTMLElement) {
  return Array.from(
    container.querySelectorAll<HTMLElement>(focusableSelector),
  ).filter(
    (element) =>
      !element.hasAttribute("disabled") &&
      element.getAttribute("aria-hidden") !== "true",
  );
}

function focusHashTarget(href: string) {
  if (!href.startsWith("#")) {
    return;
  }

  requestAnimationFrame(() => {
    const target = document.getElementById(decodeURIComponent(href.slice(1)));

    if (!target) {
      return;
    }

    if (target.tabIndex < 0) {
      target.tabIndex = -1;
    }

    target.focus({ preventScroll: true });
  });
}

export function MobileMenu({
  open,
  items,
  onClose,
  language,
}: MobileMenuProps) {
  const menuRef = useRef<HTMLDivElement>(null);
  const menuId = useId();
  const lockOwnerRef = useRef(`mobile-menu-${menuId}`);

  useEffect(() => {
    if (!open) {
      return;
    }

    const firstItem = menuRef.current?.querySelector<HTMLAnchorElement>(
      "a[href]",
    );
    firstItem?.focus();
  }, [open]);

  useEffect(() => {
    const mediaQuery = window.matchMedia("(min-width: 901px)");
    const closeOnDesktop = () => {
      if (mediaQuery.matches) {
        onClose();
      }
    };

    closeOnDesktop();
    mediaQuery.addEventListener("change", closeOnDesktop);

    return () => mediaQuery.removeEventListener("change", closeOnDesktop);
  }, [onClose]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const owner = lockOwnerRef.current;
    const main = document.querySelector<HTMLElement>("main");
    const previousOverflow = document.body.style.overflow;
    const previousInert = main?.inert;

    document.body.dataset.mobileMenuLockOwner = owner;
    document.body.style.overflow = "hidden";

    if (main) {
      main.inert = true;
    }

    return () => {
      if (document.body.dataset.mobileMenuLockOwner !== owner) {
        return;
      }

      document.body.style.overflow = previousOverflow;
      delete document.body.dataset.mobileMenuLockOwner;

      if (main) {
        main.inert = previousInert ?? false;
      }
    };
  }, [open]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
        return;
      }

      if (event.key !== "Tab" || !menuRef.current) {
        return;
      }

      const menuButton =
        document.querySelector<HTMLElement>(menuButtonSelector);
      const focusable = [
        ...getFocusableElements(menuRef.current),
        ...(menuButton ? [menuButton] : []),
      ];

      if (!focusable.length) {
        return;
      }

      const first = focusable[0];
      const last = focusable.at(-1);

      if (!last) {
        return;
      }

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKeyDown);

    return () => document.removeEventListener("keydown", onKeyDown);
  }, [onClose, open]);

  const handleLinkKeyDown = (
    event: ReactKeyboardEvent<HTMLAnchorElement>,
    href: string,
  ) => {
    if (event.key === "Enter" || event.key === " ") {
      onClose();
      focusHashTarget(href);
    }
  };

  return (
    <div
      aria-hidden={!open}
      aria-label={language === "zh-CN" ? "主导航菜单" : "Main navigation menu"}
      aria-modal="true"
      className={`${styles.menu} ${open ? styles.open : ""}`}
      id="site-menu"
      inert={!open}
      ref={menuRef}
      role="dialog"
    >
      <nav
        aria-label={language === "zh-CN" ? "主导航" : "Main navigation"}
        className={styles.nav}
      >
        {items.map((item) => {
          const isDownload = item.id === "download";
          const isExternal =
            item.isExternal || /^(?:https?:)?\/\//.test(item.href);

          return (
            <a
              className={`${styles.link} ${isDownload ? styles.download : ""}`}
              href={item.href}
              key={item.id}
              onClick={() => {
                onClose();
                focusHashTarget(item.href);
              }}
              onKeyDown={(event) => handleLinkKeyDown(event, item.href)}
              rel={isExternal ? "noopener noreferrer" : undefined}
              target={isExternal ? "_blank" : undefined}
            >
              {item.label[language]}
            </a>
          );
        })}
      </nav>
    </div>
  );
}
