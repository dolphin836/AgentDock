/**
 * Single source of truth for the published AgentDock release metadata.
 *
 * A release build (`scripts/package.sh`) stamps the shipping version and DMG
 * URL through build-time environment variables so no component keeps its own
 * hardcoded version. When the variables are absent (local dev, CI, tests) we
 * fall back to the last shipped release so the site still renders a coherent
 * download.
 *
 * These are the only values other modules should import; never re-introduce a
 * literal version or DMG URL elsewhere.
 *
 * NOTE: the expressions below are intentionally kept as a plain
 * `process.env.NEXT_PUBLIC_* || fallback` so that, once Next inlines the env
 * value, the minifier can constant-fold the `||` and drop the fallback literal.
 * That is what lets a `9.9.9` release build contain no stale `0.2.4` string —
 * see `scripts/release-regression.mjs`.
 */

const FALLBACK_VERSION = "0.2.4";
const DOWNLOAD_ORIGIN = "https://api.agentdockstatus.app/v1/download";

export const RELEASE_VERSION =
  process.env.NEXT_PUBLIC_AGENTDOCK_VERSION || FALLBACK_VERSION;

export const DOWNLOAD_URL =
  process.env.NEXT_PUBLIC_AGENTDOCK_DMG_URL ||
  `${DOWNLOAD_ORIGIN}/AgentDock-${RELEASE_VERSION}.dmg`;

/**
 * Filename for the `download` attribute. Derived from the resolved URL so the
 * saved file always matches what is actually served, falling back to the
 * version-derived name when the URL has no path segment.
 */
export const DOWNLOAD_FILENAME =
  DOWNLOAD_URL.split("/").pop() || `AgentDock-${RELEASE_VERSION}.dmg`;
