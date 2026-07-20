import Image from "next/image";
import type { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement>;

function IconFrame({ children, ...props }: IconProps) {
  return (
    <svg
      aria-hidden="true"
      fill="none"
      viewBox="0 0 24 24"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      {children}
    </svg>
  );
}

export function ArrowRightIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="M4 12h15m-5.5-5.5L19 12l-5.5 5.5" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function CheckIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="m5 12.5 4.25 4L19 7" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.9" />
    </IconFrame>
  );
}

export function ChevronDownIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="m6 9 6 6 6-6" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function DownloadIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="M12 3v11m0 0 4-4m-4 4-4-4M5 18.5v1.25c0 .69.56 1.25 1.25 1.25h11.5c.69 0 1.25-.56 1.25-1.25V18.5" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function LockIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <rect height="10" rx="2" stroke="currentColor" strokeWidth="1.75" width="14" x="5" y="10" />
      <path d="M8 10V7.5a4 4 0 1 1 8 0V10m-4 4v2" stroke="currentColor" strokeLinecap="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function MenuIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" strokeLinecap="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function NotchIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="M4 7.5A2.5 2.5 0 0 1 6.5 5h11A2.5 2.5 0 0 1 20 7.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 16.5v-9Z" stroke="currentColor" strokeWidth="1.75" />
      <path d="M9 5v1.5A1.5 1.5 0 0 0 10.5 8h3A1.5 1.5 0 0 0 15 6.5V5" stroke="currentColor" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function PrivacyIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="M12 3.5 19 6v5.75c0 4.25-2.9 7.5-7 8.75-4.1-1.25-7-4.5-7-8.75V6l7-2.5Z" stroke="currentColor" strokeLinejoin="round" strokeWidth="1.75" />
      <path d="M9.5 12.25 11.2 14 14.75 10.25" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function SparkIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <path d="m12 3 1.3 5.7L19 10l-5.7 1.3L12 17l-1.3-5.7L5 10l5.7-1.3L12 3Zm6.2 12.3.55 2.15L21 18l-2.25.55-.55 2.15-.55-2.15L16 18l2.2-.55.55-2.15Z" fill="currentColor" />
    </IconFrame>
  );
}

export function StatusIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <circle cx="12" cy="12" r="7" stroke="currentColor" strokeWidth="1.75" />
      <circle cx="12" cy="12" fill="currentColor" r="2.25" />
    </IconFrame>
  );
}

export function TerminalIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <rect height="15" rx="2" stroke="currentColor" strokeWidth="1.75" width="18" x="3" y="4.5" />
      <path d="m7 9 3 3-3 3m5 0h4" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function WindowCloseIcon(props: IconProps) {
  return (
    <IconFrame {...props}>
      <rect height="15" rx="2" stroke="currentColor" strokeWidth="1.75" width="18" x="3" y="4.5" />
      <path d="m10 10 4 4m0-4-4 4" stroke="currentColor" strokeLinecap="round" strokeWidth="1.75" />
    </IconFrame>
  );
}

export function BrandIcon({ alt = "AgentDock", className }: { alt?: string; className?: string }) {
  return (
    <Image
      alt={alt}
      className={className}
      height={48}
      priority
      src="/app-icon.png"
      width={48}
    />
  );
}
