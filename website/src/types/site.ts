export type SiteLanguage = "en" | "zh-CN";

export interface LocalizedCopy {
  en: string;
  "zh-CN": string;
}

export interface NavigationItem {
  id: string;
  label: LocalizedCopy;
  href: string;
  isExternal?: boolean;
}

export type IconName =
  | "arrow-right"
  | "check"
  | "chevron-down"
  | "download"
  | "lock"
  | "menu"
  | "notch"
  | "privacy"
  | "spark"
  | "status"
  | "terminal"
  | "window-close";

export interface ActionLink {
  label: LocalizedCopy;
  href: string;
  icon?: IconName;
  isExternal?: boolean;
}

export interface CapabilityPanel {
  id: string;
  eyebrow: LocalizedCopy;
  title: LocalizedCopy;
  description: LocalizedCopy;
  icon: IconName;
  media: {
    src: string;
    alt: LocalizedCopy;
  };
  action?: ActionLink;
}

export interface JourneyStep {
  id: string;
  sequence: string;
  title: LocalizedCopy;
  description: LocalizedCopy;
  icon: IconName;
}

export type IntegrationStatus = "available" | "planned";

export interface Integration {
  id: string;
  name: string;
  description: LocalizedCopy;
  status: IntegrationStatus;
  icon: IconName;
}

export interface PrivacyPoint {
  id: string;
  title: LocalizedCopy;
  description: LocalizedCopy;
  icon: IconName;
}

export interface PrivacySection {
  eyebrow: LocalizedCopy;
  title: LocalizedCopy;
  description: LocalizedCopy;
  points: PrivacyPoint[];
  action?: ActionLink;
}

export interface SiteContent {
  language: SiteLanguage;
  navigation: NavigationItem[];
  capabilities: CapabilityPanel[];
  journey: JourneyStep[];
  integrations: Integration[];
  privacy: PrivacySection;
}
