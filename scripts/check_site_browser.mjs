// [skill: go-team-standards · 部署发布] 用现有 Puppeteer 验证 Next 静态导出
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
  const types = { ".css": "text/css", ".html": "text/html", ".js": "text/javascript",
    ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml",
    ".woff2": "font/woff2" };
  const server = createServer(async (request, response) => {
    try {
      const requestPath = new URL(request.url, requestedUrl).pathname;
      const relative = requestPath === "/" ? "index.html" : requestPath.slice(1);
      const file = path.resolve(SITE, relative);
      if (!file.startsWith(`${SITE}${path.sep}`)) throw new Error("outside site");
      response.writeHead(200, { "content-type": types[path.extname(file)] ?? "application/octet-stream" });
      response.end(await readFile(file));
    } catch {
      response.writeHead(404).end();
    }
  });
  return new Promise((resolve) => server.listen(4174, "127.0.0.1", () => resolve(server)));
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
    await page.setViewport({ ...viewport, deviceScaleFactor: 1, isMobile: viewport.width <= 900 });
    await page.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: media }]);
    await page.goto(requestedUrl, { waitUntil: "networkidle0", timeout: 30_000 });
    await page.waitForSelector("#hero-title");
  };
  const noOverflow = async (label) => {
    const width = await page.evaluate(() => ({
      viewport: innerWidth, scroll: document.documentElement.scrollWidth,
    }));
    assert(width.scroll <= width.viewport, `${label} has no horizontal overflow`);
  };

  await load({ width: 1440, height: 1000 });
  await noOverflow("1440px desktop");
  const desktop = await page.evaluate(() => ({
    hero: Boolean(document.querySelector("#top canvas")),
    header: document.querySelector("header")?.getAttribute("data-scrolled"),
    download: [...document.querySelectorAll("a[href]")].filter((a) =>
      a.href.includes("AgentDock-0.2.4.dmg")).length,
  }));
  assert(desktop.hero, "hero canvas renders in the static export");
  assert(desktop.download >= 2, "real v0.2.4 DMG remains linked");
  await page.evaluate(() => scrollTo(0, innerHeight));
  await page.waitForFunction(() => document.querySelector("header")?.getAttribute("data-scrolled") === "true");
  assert(true, "header switches to its scrolled state");

  const journey = await page.evaluate(async () => {
    const section = document.querySelector("#meeting");
    section?.scrollIntoView();
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return {
      slideCount: document.querySelectorAll("#meeting [data-slide-index]").length,
      wide: innerWidth > 900,
    };
  });
  assert(journey.wide && journey.slideCount === 4, "desktop journey exposes four pinned-track slides");

  await load({ width: 390, height: 844 });
  await noOverflow("390px mobile");
  await page.click("[data-mobile-menu-button]");
  await page.waitForFunction(() => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "false");
  const menu = await page.evaluate(() => ({
    expanded: document.querySelector("[data-mobile-menu-button]")?.getAttribute("aria-expanded"),
    focused: Boolean(document.activeElement?.closest("#site-menu")),
    modal: document.querySelector("#site-menu")?.getAttribute("aria-modal"),
  }));
  assert(menu.expanded === "true" && menu.focused && menu.modal === "true", "mobile menu opens with focus and ARIA state");
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "true");
  assert(true, "Escape closes the mobile menu");

  await page.click("[role='tab']:nth-of-type(1)");
  await page.keyboard.press("ArrowRight");
  const tabs = await page.evaluate(() => ({
    selected: document.activeElement?.getAttribute("aria-selected"),
    panel: document.getElementById(document.activeElement?.getAttribute("aria-controls") ?? "")?.getAttribute("role"),
  }));
  assert(tabs.selected === "true" && tabs.panel === "tabpanel", "voice tabs maintain keyboard ARIA linkage");

  const initialLanguage = await page.evaluate(() => document.documentElement.lang);
  await page.click("button[aria-label^='Switch to']");
  const toggledLanguage = await page.evaluate(() => document.documentElement.lang);
  assert(
    new Set([initialLanguage, toggledLanguage]).size === 2 &&
      ["en", "zh-CN"].includes(toggledLanguage),
    "language toggle switches between English and Chinese",
  );

  await load({ width: 390, height: 844 }, "reduce");
  await noOverflow("390px reduced-motion");
  const reduced = await page.evaluate(() => ({
    canvas: Boolean(document.querySelector("#context-focus-canvas")),
    meetingVertical: getComputedStyle(document.querySelector("#meeting-journey")?.parentElement).overflowX,
  }));
  assert(reduced.canvas && reduced.meetingVertical !== "hidden", "canvas fallback and reduced-motion journey degradation remain available");
  assert(errors.length === 0, `console has no errors (${errors.join("; ")})`);
  console.log("PASS: browser Next.js static site contract");
} finally {
  await browser.close();
  await new Promise((resolve) => fallbackServer?.close(resolve) ?? resolve());
}
