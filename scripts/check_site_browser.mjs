// [skill: go-team-standards · 部署发布] 用现有 Puppeteer 验证单屏 Next 静态导出
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SITE = path.join(ROOT, "site");
const require = createRequire(path.join(ROOT, "website", "package.json"));
const puppeteer = require("puppeteer-core");
const chromePath =
  process.env.CHROME_PATH ??
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const requestedUrl = process.env.SITE_URL ?? "http://127.0.0.1:4174/";

function assert(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`ok - ${message}`);
}

function serveStaticSite() {
  const types = {
    ".css": "text/css",
    ".html": "text/html",
    ".js": "text/javascript",
    ".json": "application/json",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".woff2": "font/woff2",
  };
  const server = createServer(async (request, response) => {
    try {
      const requestPath = new URL(request.url, requestedUrl).pathname;
      const relative = requestPath === "/" ? "index.html" : requestPath.slice(1);
      const file = path.resolve(SITE, relative);
      if (!file.startsWith(`${SITE}${path.sep}`)) throw new Error("outside site");
      response.writeHead(200, {
        "content-type": types[path.extname(file)] ?? "application/octet-stream",
      });
      response.end(await readFile(file));
    } catch {
      response.writeHead(404).end();
    }
  });
  return new Promise((resolve) =>
    server.listen(4174, "127.0.0.1", () => resolve(server)),
  );
}

let fallbackServer;
try {
  await fetch(requestedUrl, { signal: AbortSignal.timeout(1_000) });
} catch {
  fallbackServer = await serveStaticSite();
}

const browser = await puppeteer.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--no-sandbox", "--no-first-run", "--disable-background-networking"],
});
const errors = [];

try {
  const page = await browser.newPage();
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));

  const load = async (viewport, media = "no-preference") => {
    await page.setViewport({
      ...viewport,
      deviceScaleFactor: 1,
      isMobile: viewport.width <= 900,
    });
    await page.emulateMediaFeatures([
      { name: "prefers-reduced-motion", value: media },
    ]);
    await page.goto(requestedUrl, {
      waitUntil: "networkidle0",
      timeout: 30_000,
    });
    await page.waitForSelector("#hero-title");
  };

  const measure = async () =>
    page.evaluate(() => {
      const hero = document.querySelector("#top");
      const dotLayer = hero?.querySelector("div");
      return {
        viewport: { width: innerWidth, height: innerHeight },
        document: {
          width: document.documentElement.scrollWidth,
          height: document.documentElement.scrollHeight,
        },
        heroHeight: hero?.getBoundingClientRect().height ?? 0,
        sectionCount: document.querySelectorAll("main > section").length,
        footerCount: document.querySelectorAll("footer").length,
        hasCanvas: Boolean(hero?.querySelector("canvas")),
        hasDots:
          dotLayer instanceof HTMLElement &&
          getComputedStyle(dotLayer).backgroundImage.includes("hero-dot-grid.png"),
        downloadCount: [...document.querySelectorAll("a[href]")].filter((anchor) =>
          anchor.href.includes("AgentDock-0.2.4.dmg"),
        ).length,
      };
    });

  for (const viewport of [
    { width: 1440, height: 1000 },
    { width: 390, height: 844 },
  ]) {
    await load(viewport);
    const state = await measure();
    const label = `${viewport.width}x${viewport.height}`;
    assert(
      state.document.width <= state.viewport.width,
      `${label} has no horizontal overflow`,
    );
    assert(
      state.document.height === state.viewport.height &&
        state.heroHeight === state.viewport.height,
      `${label} is exactly one viewport tall`,
    );
    assert(
      state.sectionCount === 1 && state.footerCount === 0,
      `${label} contains only the hero section`,
    );
    assert(state.hasCanvas && state.hasDots, `${label} renders particles over dots`);
    assert(state.downloadCount >= 2, `${label} retains the v0.2.4 download links`);
  }

  await page.click("[data-mobile-menu-button]");
  await page.waitForFunction(
    () => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "false",
  );
  const menu = await page.evaluate(() => ({
    expanded: document
      .querySelector("[data-mobile-menu-button]")
      ?.getAttribute("aria-expanded"),
    focused: Boolean(document.activeElement?.closest("#site-menu")),
    modal: document.querySelector("#site-menu")?.getAttribute("aria-modal"),
  }));
  assert(
    menu.expanded === "true" && menu.focused && menu.modal === "true",
    "mobile menu opens with focus and ARIA state",
  );
  await page.keyboard.press("Escape");
  await page.waitForFunction(
    () => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "true",
  );
  assert(true, "Escape closes the mobile menu");

  const initialLanguage = await page.evaluate(() => document.documentElement.lang);
  await page.click("button[aria-label^='Switch to']");
  const toggledLanguage = await page.evaluate(() => document.documentElement.lang);
  assert(
    new Set([initialLanguage, toggledLanguage]).size === 2 &&
      ["en", "zh-CN"].includes(toggledLanguage),
    "language toggle switches between English and Chinese",
  );

  await load({ width: 390, height: 844 }, "reduce");
  const reduced = await measure();
  assert(
    reduced.hasCanvas && reduced.hasDots && reduced.document.height === 844,
    "reduced-motion mode keeps the complete one-screen hero",
  );
  assert(errors.length === 0, `console has no errors (${errors.join("; ")})`);
  console.log("PASS: browser Next.js one-screen static site contract");
} finally {
  await browser.close();
  await new Promise((resolve) => fallbackServer?.close(resolve) ?? resolve());
}
