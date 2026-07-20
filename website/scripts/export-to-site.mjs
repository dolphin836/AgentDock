import { cp, readdir, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Locate the website root from this script's own location (import.meta.url) so
// the copy works regardless of the caller's cwd — the release pipeline invokes
// it from the repo root after building with the shipping env.
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const websiteRoot = path.resolve(scriptDir, "..");
const sourceDir = path.join(websiteRoot, "out");
const siteDir = path.resolve(websiteRoot, "..", "site");

// Top-level entries the published site owns outside of the Next export: the
// admin console, the release manifest, the shipped DMG(s), the macOS updater
// feed, and the brand assets. Everything else at the top level is a Next export
// artifact and is cleared before copying the fresh `out/` manifest.
const PRESERVE = new Set([
  "admin.html",
  "version.json",
  "macos",
  "app-icon.png",
  "apple-touch-icon.png",
  "favicon.ico",
  "favicon.png",
  "hero-wallpaper.jpg",
]);

function shouldPreserve(name) {
  return PRESERVE.has(name) || name.endsWith(".dmg");
}

// Clear every previous Next export item at the top level while keeping the
// preserved app-shell resources, so stale routes/chunks never linger.
for (const entry of await readdir(siteDir)) {
  if (shouldPreserve(entry)) {
    continue;
  }
  await rm(path.join(siteDir, entry), { force: true, recursive: true });
}

// The freshly built `out/` directory is the manifest of what to publish.
for (const entry of await readdir(sourceDir)) {
  await cp(path.join(sourceDir, entry), path.join(siteDir, entry), {
    force: true,
    recursive: true,
  });
}

console.log(`Exported ${sourceDir} to ${siteDir}`);
