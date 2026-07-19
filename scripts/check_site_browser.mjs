// [skill: go-team-standards · 可执行回归] 使用 Node 内置能力和本机 Chrome CDP 验证移动菜单
import { spawn } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, stat, writeFile } from "node:fs/promises";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const siteArg = process.argv.indexOf("--site-dir");
const SITE = path.resolve(siteArg >= 0 ? process.argv[siteArg + 1] : path.join(ROOT, "site"));
const screenshotArg = process.argv.indexOf("--screenshot-dir");
const SCREENSHOT_DIR =
  screenshotArg >= 0 ? path.resolve(process.argv[screenshotArg + 1]) : null;
const CHROME =
  process.env.CHROME_PATH ||
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const mime = new Map([
  [".css", "text/css"],
  [".html", "text/html"],
  [".jpg", "image/jpeg"],
  [".js", "text/javascript"],
  [".json", "application/json"],
  [".png", "image/png"],
]);

function fail(message) {
  throw new Error(message);
}

function check(condition, message) {
  if (!condition) fail(message);
  console.log(`ok - ${message}`);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function serveSite() {
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, "http://127.0.0.1");
      const relative = url.pathname === "/" ? "index.html" : url.pathname.slice(1);
      const file = path.resolve(SITE, decodeURIComponent(relative));
      if (file !== SITE && !file.startsWith(`${SITE}${path.sep}`)) {
        response.writeHead(403).end();
        return;
      }
      const body = await readFile(file);
      response.writeHead(200, {
        "content-type": mime.get(path.extname(file)) || "application/octet-stream",
      });
      response.end(body);
    } catch {
      response.writeHead(404).end();
    }
  });
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function waitForDevToolsPort(profile) {
  const activePort = path.join(profile, "DevToolsActivePort");
  for (let attempt = 0; attempt < 100; attempt += 1) {
    try {
      const [port] = (await readFile(activePort, "utf8")).split("\n");
      if (port) return Number(port);
    } catch {
      await sleep(50);
    }
  }
  fail("Chrome did not publish a DevTools port");
}

class CDP {
  constructor(socket) {
    this.socket = socket;
    this.sequence = 0;
    this.pending = new Map();
    socket.addEventListener("message", ({ data }) => {
      const message = JSON.parse(data);
      if (!message.id) return;
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      this.pending.delete(message.id);
      if (message.error) waiter.reject(new Error(message.error.message));
      else waiter.resolve(message.result);
    });
  }

  send(method, params = {}) {
    const id = ++this.sequence;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (result.exceptionDetails) fail(result.exceptionDetails.text || "browser evaluation failed");
    return result.result.value;
  }
}

async function connectPage(port, url) {
  const target = await fetch(
    `http://127.0.0.1:${port}/json/new?${encodeURIComponent(url)}`,
    { method: "PUT" },
  ).then((response) => response.json());
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });
  return new CDP(socket);
}

async function setViewport(cdp, width, height) {
  await cdp.send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width <= 900,
  });
}

async function load(cdp, url) {
  await cdp.send("Page.enable");
  await cdp.send("Runtime.enable");
  await cdp.send("Page.navigate", { url });
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const ready = await cdp.evaluate("document.readyState === 'complete'");
    if (ready) return;
    await sleep(50);
  }
  fail("site did not finish loading");
}

async function run() {
  await stat(path.join(SITE, "index.html"));
  await stat(CHROME);

  const server = await serveSite();
  const profile = await mkdtemp(path.join(os.tmpdir(), "agentdock-cdp-"));
  const chrome = spawn(
    CHROME,
    [
      "--headless=new",
      "--remote-debugging-port=0",
      `--user-data-dir=${profile}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-background-networking",
      "--disable-component-update",
      "--disable-sync",
      "--no-sandbox",
    ],
    { stdio: "ignore" },
  );

  try {
    const port = await waitForDevToolsPort(profile);
    const url = `http://127.0.0.1:${server.address().port}/index.html`;
    const cdp = await connectPage(port, "about:blank");

    await setViewport(cdp, 390, 844);
    await load(cdp, url);
    await sleep(250);

    const mobile = await cdp.evaluate(`(() => {
      const button = document.getElementById("menuButton");
      return {
        width: innerWidth,
        height: innerHeight,
        buttonDisplay: getComputedStyle(button).display,
        navDisplay: getComputedStyle(document.querySelector(".nav-center")).display,
      };
    })()`);
    check(mobile.width === 390 && mobile.height === 844, "390x844 mobile viewport applied");
    check(mobile.buttonDisplay !== "none" && mobile.navDisplay === "none", "mobile navigation mode active");

    await cdp.evaluate(`document.getElementById("menuButton").click()`);
    await sleep(100);
    const opened = await cdp.evaluate(`(() => {
      const menu = document.getElementById("mobileMenu");
      return {
        expanded: document.getElementById("menuButton").getAttribute("aria-expanded"),
        hidden: menu.getAttribute("aria-hidden"),
        firstFocused: document.activeElement === menu.querySelector(".mobile-link"),
      };
    })()`);
    check(opened.expanded === "true" && opened.hidden === "false", "mobile menu opens with ARIA state");
    check(opened.firstFocused, "mobile menu focuses first link");

    await cdp.evaluate(`window.scrollTo(0, 3000)`);
    await sleep(500);
    const scrolled = await cdp.evaluate(`(() => {
      const header = document.getElementById("siteHeader");
      const button = document.getElementById("menuButton");
      const rect = button.getBoundingClientRect();
      const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
      return {
        menuOpen: document.getElementById("mobileMenu").classList.contains("is-open"),
        headerHidden: header.classList.contains("is-hidden"),
        buttonTop: rect.top,
        buttonBottom: rect.bottom,
        reachable: hit === button || button.contains(hit),
      };
    })()`);
    check(scrolled.menuOpen, "mobile menu remains open after downward scroll");
    check(!scrolled.headerHidden, "header remains visible while mobile menu is open");
    check(
      scrolled.buttonTop >= 0 && scrolled.buttonBottom <= 844 && scrolled.reachable,
      "close button remains visible and reachable after scroll",
    );

    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyDown",
      key: "Escape",
      code: "Escape",
      windowsVirtualKeyCode: 27,
    });
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyUp",
      key: "Escape",
      code: "Escape",
      windowsVirtualKeyCode: 27,
    });
    await sleep(100);
    const closed = await cdp.evaluate(`(() => {
      const button = document.getElementById("menuButton");
      const menu = document.getElementById("mobileMenu");
      return {
        expanded: button.getAttribute("aria-expanded"),
        hidden: menu.getAttribute("aria-hidden"),
        buttonFocused: document.activeElement === button,
      };
    })()`);
    check(closed.expanded === "false" && closed.hidden === "true", "Escape closes mobile menu");
    check(closed.buttonFocused, "Escape restores focus to menu button");

    await setViewport(cdp, 360, 800);
    await load(cdp, url);
    const narrow = await cdp.evaluate(`({
      width: innerWidth,
      height: innerHeight,
      noOverflow: document.documentElement.scrollWidth <= innerWidth,
      buttonVisible: getComputedStyle(document.getElementById("menuButton")).display !== "none"
    })`);
    check(narrow.width === 360 && narrow.height === 800, "360x800 mobile viewport applied");
    check(narrow.noOverflow && narrow.buttonVisible, "360px layout has no overflow and keeps menu control");

    await setViewport(cdp, 1440, 1000);
    await load(cdp, `${url}?context-density`);
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const curtainDone = await cdp.evaluate(
        `["complete", "skipped"].includes(window.AgentDockCurtain?.state)`,
      );
      if (curtainDone) break;
      await sleep(50);
    }
    await cdp.evaluate(`(() => {
      const section = document.getElementById("context");
      window.scrollTo({
        top: section.getBoundingClientRect().top + window.scrollY,
        left: 0,
        behavior: "instant",
      });
    })()`);
    for (let attempt = 0; attempt < 100; attempt += 1) {
      if (await cdp.evaluate("Boolean(window.AgentDockContext?.ready)")) break;
      await sleep(50);
    }
    await sleep(700);
    const context = await cdp.evaluate(`(() => {
      const api = window.AgentDockContext;
      const canvas = document.getElementById("contextCanvas");
      return {
        mode: api?.mode,
        count: api?.config?.count,
        pointSize: api?.config?.pointSize,
        alphaBase: api?.config?.alphaBase,
        alphaPeak: api?.config?.alphaPeak,
        sectionTop: Math.round(document.getElementById("context").getBoundingClientRect().top),
        frames: api?.frameCount,
        mask: getComputedStyle(canvas).maskImage,
      };
    })()`);
    check(context.mode === "webgl", "context particle field renders with WebGL");
    check(
      Math.abs(context.sectionTop) <= 2 && context.frames > 1,
      `context scene is visible and rendering frames (top=${context.sectionTop}, frames=${context.frames})`,
    );
    check(context.count >= 4000, "capable desktop context field uses dense particle tier");
    check(
      context.pointSize >= 4.8 && context.alphaBase >= 0.28 && context.alphaPeak >= 0.9,
      "context particles expose reference-density size and opacity",
    );
    check(
      context.mask.includes("12%") && context.mask.includes("88%"),
      "context mask preserves a broad visible middle band",
    );
    if (SCREENSHOT_DIR) {
      await mkdir(SCREENSHOT_DIR, { recursive: true });
      const capture = await cdp.send("Page.captureScreenshot", {
        format: "png",
        fromSurface: true,
      });
      await writeFile(
        path.join(SCREENSHOT_DIR, "t6-1440-context-density-final.png"),
        Buffer.from(capture.data, "base64"),
      );
    }

    await cdp.send("Page.addScriptToEvaluateOnNewDocument", {
      source: `(() => {
        Object.defineProperty(navigator, "connection", { configurable: true, value: { saveData: true } });
        Object.defineProperty(navigator, "deviceMemory", { configurable: true, value: 2 });
        Object.defineProperty(navigator, "hardwareConcurrency", { configurable: true, value: 2 });
      })();`,
    });
    await load(cdp, `${url}?constrained-context`);
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const curtainDone = await cdp.evaluate(
        `["complete", "skipped"].includes(window.AgentDockCurtain?.state)`,
      );
      if (curtainDone) break;
      await sleep(50);
    }
    await cdp.evaluate(`(() => {
      const section = document.getElementById("context");
      window.scrollTo({
        top: section.getBoundingClientRect().top + window.scrollY,
        left: 0,
        behavior: "instant",
      });
    })()`);
    for (let attempt = 0; attempt < 100; attempt += 1) {
      if (await cdp.evaluate("Boolean(window.AgentDockContext?.ready)")) break;
      await sleep(50);
    }
    const constrainedCount = await cdp.evaluate("window.AgentDockContext?.config?.count");
    check(constrainedCount === 1600, "saveData and low-memory context tier uses 1600 particles");

    console.log("PASS: browser site contract");
  } finally {
    chrome.kill("SIGTERM");
    await Promise.race([
      new Promise((resolve) => chrome.once("exit", resolve)),
      sleep(2000),
    ]);
    await new Promise((resolve) => server.close(resolve));
    await rm(profile, { recursive: true, force: true });
  }
}

run().catch((error) => {
  console.error(`FAIL: ${error.message}`);
  process.exitCode = 1;
});
