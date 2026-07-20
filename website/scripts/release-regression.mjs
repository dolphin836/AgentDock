#!/usr/bin/env node
// [skill: go-team-standards · 可复现发布回归] 用哨兵版本重建站点,断言产物只含哨兵版本,
// 且语言自动切换 / 手动 toggle 后下载 href 与版本仍为哨兵值,最后恢复默认构建。
//
// Release path authority: the shipping version is baked into the Next static
// export at build time (website/src/lib/release.ts reads NEXT_PUBLIC_* env).
// This regression builds `out/` with a sentinel version, verifies it, and then
// rebuilds with the default env so the working tree keeps the real export.
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const websiteRoot = path.resolve(scriptDir, "..");
const outDir = path.join(websiteRoot, "out");

const SENTINEL_VERSION = "9.9.9";
const SENTINEL_URL =
  `https://api.agentdockstatus.app/v1/download/AgentDock-${SENTINEL_VERSION}.dmg`;
const STALE_VERSION = "0.2.4";

const PORT = Number(process.env.RELEASE_REGRESSION_PORT ?? 4185);
const BASE_URL = `http://127.0.0.1:${PORT}/`;
const chromePath =
  process.env.CHROME_PATH ??
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const require = createRequire(path.join(websiteRoot, "package.json"));

function assert(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`ok - ${message}`);
}

function buildSite(env, label, { clearReleaseEnv = false } = {}) {
  console.log(`\n[build] ${label}`);
  const childEnv = { ...process.env };
  if (clearReleaseEnv) {
    delete childEnv.NEXT_PUBLIC_AGENTDOCK_VERSION;
    delete childEnv.NEXT_PUBLIC_AGENTDOCK_DMG_URL;
  }
  Object.assign(childEnv, env);
  execFileSync("npm", ["run", "build"], {
    cwd: websiteRoot,
    stdio: "inherit",
    env: childEnv,
  });
}

async function collectFiles(dir, predicate) {
  const results = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...(await collectFiles(full, predicate)));
    } else if (predicate(entry.name)) {
      results.push(full);
    }
  }
  return results;
}

async function assertStaticOutput() {
  console.log("\n[assert] static export");
  const html = await readFile(path.join(outDir, "index.html"), "utf8");
  assert(!html.includes(STALE_VERSION), `index.html has no stale ${STALE_VERSION}`);
  assert(html.includes(SENTINEL_VERSION), `index.html includes ${SENTINEL_VERSION}`);
  assert(html.includes(SENTINEL_URL), "index.html includes the sentinel DMG URL");

  const jsFiles = await collectFiles(
    path.join(outDir, "_next"),
    (name) => name.endsWith(".js"),
  );
  assert(jsFiles.length > 0, "found hashed JS chunks under _next");

  let sawSentinel = false;
  for (const file of jsFiles) {
    const contents = await readFile(file, "utf8");
    if (contents.includes(STALE_VERSION)) {
      throw new Error(
        `hashed JS ${path.relative(outDir, file)} still contains ${STALE_VERSION}`,
      );
    }
    if (contents.includes(SENTINEL_VERSION)) sawSentinel = true;
  }
  assert(true, `no hashed JS contains ${STALE_VERSION}`);
  assert(sawSentinel, `some hashed JS contains ${SENTINEL_VERSION}`);
}

function serveStaticSite() {
  const types = {
    ".css": "text/css",
    ".html": "text/html",
    ".js": "text/javascript",
    ".json": "application/json",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".svg": "image/svg+xml",
    ".woff2": "font/woff2",
    ".ico": "image/x-icon",
    ".txt": "text/plain",
  };
  const server = createServer(async (request, response) => {
    try {
      const requestPath = new URL(request.url, BASE_URL).pathname;
      const relative = requestPath === "/" ? "index.html" : requestPath.slice(1);
      let file = path.resolve(outDir, relative);
      if (file !== outDir && !file.startsWith(`${outDir}${path.sep}`)) {
        throw new Error("outside out");
      }
      // trailingSlash export maps /route/ -> /route/index.html
      if (requestPath.endsWith("/") && requestPath !== "/") {
        file = path.join(file, "index.html");
      }
      response.writeHead(200, {
        "content-type": types[path.extname(file)] ?? "application/octet-stream",
      });
      response.end(await readFile(file));
    } catch {
      response.writeHead(404).end();
    }
  });
  return new Promise((resolve) =>
    server.listen(PORT, "127.0.0.1", () => resolve(server)),
  );
}

async function readDownloadState(page) {
  return page.evaluate((sentinelUrl) => {
    const anchors = [...document.querySelectorAll("a[href]")];
    const dmgAnchors = anchors.filter((a) => a.href.includes("AgentDock-"));
    const versionSection = document.querySelector("#download");
    return {
      lang: document.documentElement.lang,
      dmgCount: dmgAnchors.length,
      allSentinel: dmgAnchors.every((a) => a.href === sentinelUrl),
      dataVersion: versionSection?.getAttribute("data-version") ?? null,
      metadataText: document.querySelector("#final-cta-heading")
        ?.closest("section")
        ?.textContent ?? "",
    };
  }, SENTINEL_URL);
}

async function runBrowserChecks() {
  console.log("\n[assert] hydrated download href / version survive language switch");
  const puppeteer = require("puppeteer-core");
  const server = await serveStaticSite();
  const browser = await puppeteer.launch({
    executablePath: chromePath,
    headless: true,
    args: ["--no-sandbox", "--no-first-run", "--disable-background-networking"],
  });
  const errors = [];
  try {
    const page = await browser.newPage();
    page.on("console", (m) => {
      if (m.type() === "error") errors.push(m.text());
    });
    page.on("pageerror", (e) => errors.push(e.message));

    // Auto language: emulate a Chinese browser so the site auto-switches on load.
    await page.setExtraHTTPHeaders({ "Accept-Language": "zh-CN,zh;q=0.9" });
    await page.evaluateOnNewDocument(() => {
      Object.defineProperty(navigator, "language", {
        get: () => "zh-CN",
        configurable: true,
      });
      Object.defineProperty(navigator, "languages", {
        get: () => ["zh-CN", "zh"],
        configurable: true,
      });
    });

    await page.setViewport({ width: 1440, height: 1000, deviceScaleFactor: 1 });
    await page.goto(BASE_URL, { waitUntil: "networkidle0", timeout: 60_000 });
    await page.waitForSelector("#hero-title");
    await page.waitForFunction(
      () => document.documentElement.lang === "zh-CN",
      { timeout: 10_000 },
    );

    const auto = await readDownloadState(page);
    assert(auto.lang === "zh-CN", "site auto-switched to Chinese");
    assert(auto.dmgCount >= 2, "download links present after auto switch");
    assert(auto.allSentinel, `all download hrefs are ${SENTINEL_VERSION} (auto zh)`);
    assert(auto.dataVersion === SENTINEL_VERSION, `data-version is ${SENTINEL_VERSION} (auto zh)`);
    assert(
      auto.metadataText.includes(SENTINEL_VERSION) &&
        !auto.metadataText.includes(STALE_VERSION),
      `final CTA shows v${SENTINEL_VERSION} and no ${STALE_VERSION} (auto zh)`,
    );

    // Manual toggle back to English via the header language button (its
    // aria-label is always English: "Switch to English" / "Switch to Chinese").
    await page.click("button[aria-label^='Switch to']");
    await page.waitForFunction(
      () => document.documentElement.lang === "en",
      { timeout: 10_000 },
    );
    const manual = await readDownloadState(page);
    assert(manual.lang === "en", "manual toggle switched to English");
    assert(manual.allSentinel, `all download hrefs are ${SENTINEL_VERSION} (manual en)`);
    assert(manual.dataVersion === SENTINEL_VERSION, `data-version is ${SENTINEL_VERSION} (manual en)`);
    assert(
      manual.metadataText.includes(SENTINEL_VERSION) &&
        !manual.metadataText.includes(STALE_VERSION),
      `final CTA shows v${SENTINEL_VERSION} and no ${STALE_VERSION} (manual en)`,
    );

    assert(errors.length === 0, `console has no errors (${errors.join("; ")})`);
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
}

async function main() {
  try {
    buildSite(
      {
        NEXT_PUBLIC_AGENTDOCK_VERSION: SENTINEL_VERSION,
        NEXT_PUBLIC_AGENTDOCK_DMG_URL: SENTINEL_URL,
      },
      `sentinel version ${SENTINEL_VERSION}`,
    );
    await assertStaticOutput();
    await runBrowserChecks();
    console.log("\nPASS: release regression (sentinel version isolated in output)");
  } finally {
    // Restore the default export so the working tree keeps the shipping build.
    buildSite({}, "restore default version", { clearReleaseEnv: true });
  }
}

await main();
