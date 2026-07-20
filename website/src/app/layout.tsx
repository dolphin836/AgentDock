import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://agentdockstatus.app"),
  title: "AgentDock | Every AI agent, at a glance",
  description:
    "AgentDock keeps Claude Code, Codex, and Cursor visible in your macOS notch, with live status, approvals, usage, and one-click return.",
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: "/favicon.png",
    apple: "/apple-touch-icon.png",
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    siteName: "AgentDock",
    title: "AgentDock | Every AI agent, at a glance",
    description:
      "Live agent status, approvals, usage, and workspace return in your macOS notch.",
    images: ["/app-icon.png"],
  },
  twitter: {
    card: "summary",
    title: "AgentDock | Every AI agent, at a glance",
    description:
      "Live agent status, approvals, usage, and workspace return in your macOS notch.",
    images: ["/app-icon.png"],
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#111111",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <body className="min-h-full">{children}</body>
    </html>
  );
}
