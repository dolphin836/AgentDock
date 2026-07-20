import Image from "next/image";

import styles from "./footer.module.css";

export type FooterAnchor =
  | "status"
  | "approval"
  | "usage"
  | "return"
  | "integrations"
  | "privacy"
  | "download";

export type FooterAnchors = Record<FooterAnchor, string>;

export type FooterContent = {
  tagline: string;
  navigationLabel: string;
  navigation: Record<FooterAnchor, string>;
  contactLabel: string;
  contact: ReadonlyArray<{
    label: string;
    anchor: FooterAnchor;
  }>;
  legal: string;
};

// A build-time constant keeps the static export deterministic: reading
// `new Date().getFullYear()` at render time would mismatch between the prebuilt
// HTML and client hydration once the year rolls over (hydration drift).
const COPYRIGHT_YEAR = 2026;

export const footerContent = {
  en: {
    tagline: "Every AI agent, at a glance.",
    navigationLabel: "Explore",
    navigation: {
      status: "Live status",
      approval: "Approvals",
      usage: "Usage",
      return: "One-click return",
      integrations: "Integrations",
      privacy: "Privacy",
      download: "Download",
    },
    contactLabel: "Get AgentDock",
    contact: [
      { label: "Download for macOS", anchor: "download" },
      { label: "Privacy & support", anchor: "privacy" },
    ],
    legal: "AgentDock is built for focused agent work.",
  },
  zh: {
    tagline: "所有 AI 智能体，一眼掌握。",
    navigationLabel: "探索",
    navigation: {
      status: "实时状态",
      approval: "授权审批",
      usage: "用量",
      return: "一键返回",
      integrations: "集成",
      privacy: "隐私",
      download: "下载",
    },
    contactLabel: "获取 AgentDock",
    contact: [
      { label: "下载 macOS 版", anchor: "download" },
      { label: "隐私与支持", anchor: "privacy" },
    ],
    legal: "AgentDock 为专注的智能体工作流而生。",
  },
} satisfies Record<"en" | "zh", FooterContent>;

const defaultAnchors: FooterAnchors = {
  status: "#status",
  approval: "#approval",
  usage: "#usage",
  return: "#return",
  integrations: "#integrations",
  privacy: "#privacy",
  download: "#download",
};

const navigationOrder: ReadonlyArray<FooterAnchor> = [
  "status",
  "approval",
  "usage",
  "return",
  "integrations",
  "privacy",
  "download",
];

export type FooterProps = {
  anchors?: Partial<FooterAnchors>;
  className?: string;
  content?: FooterContent;
};

function FooterLink({ href, label }: { href: string; label: string }) {
  const isExternal = /^(?:https?:)?\/\//.test(href);

  return (
    <a
      className={styles.link}
      href={href}
      rel={isExternal ? "noopener noreferrer" : undefined}
      target={isExternal ? "_blank" : undefined}
    >
      {label}
    </a>
  );
}

export function Footer({
  anchors: anchorOverrides,
  className,
  content = footerContent.en,
}: FooterProps) {
  const anchors = { ...defaultAnchors, ...anchorOverrides };
  const footerClassName = [styles.footer, className].filter(Boolean).join(" ");

  return (
    <footer className={footerClassName} data-header="dark" id="footer">
      <div className={styles.inner}>
        <div className={styles.brand}>
          <Image
            alt=""
            aria-hidden="true"
            className={styles.icon}
            height={32}
            src="/app-icon.png"
            width={32}
          />
          <p className={styles.brandName}>AgentDock</p>
          <p className={styles.tagline}>{content.tagline}</p>
        </div>

        <nav aria-label={content.navigationLabel} className={styles.linkGroup}>
          <p className={styles.groupLabel}>{content.navigationLabel}</p>
          <div className={styles.linkList}>
            {navigationOrder.map((anchor) => (
              <FooterLink
                href={anchors[anchor]}
                key={anchor}
                label={content.navigation[anchor]}
              />
            ))}
          </div>
        </nav>

        <div className={styles.linkGroup}>
          <p className={styles.groupLabel}>{content.contactLabel}</p>
          <div className={styles.linkList}>
            {content.contact.map((link) => (
              <FooterLink
                href={anchors[link.anchor]}
                key={`${link.anchor}-${link.label}`}
                label={link.label}
              />
            ))}
          </div>
        </div>

        <div className={styles.legal}>
          <span>© {COPYRIGHT_YEAR} AgentDock</span>
          <span>{content.legal}</span>
        </div>
      </div>
    </footer>
  );
}
