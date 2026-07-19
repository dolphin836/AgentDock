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
        curtainState: window.AgentDockCurtain?.state,
        mainInert: document.getElementById("main").hasAttribute("inert"),
        footerInert: document.querySelector("footer").hasAttribute("inert"),
      };
    })()`);
    check(mobile.width === 390 && mobile.height === 844, "390x844 mobile viewport applied");
    check(mobile.buttonDisplay !== "none" && mobile.navDisplay === "none", "mobile navigation mode active");
    check(
      mobile.curtainState === "skipped" && !mobile.mainInert && !mobile.footerInert,
      "skipped curtain leaves main and footer available",
    );

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
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyDown",
      key: "Tab",
      code: "Tab",
      windowsVirtualKeyCode: 9,
      modifiers: 8,
    });
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyUp",
      key: "Tab",
      code: "Tab",
      windowsVirtualKeyCode: 9,
      modifiers: 8,
    });
    const trapBack = await cdp.evaluate(
      `document.activeElement === document.getElementById("menuButton")`,
    );
    check(trapBack, "Shift+Tab cycles from first menu link to the close button");
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyDown",
      key: "Tab",
      code: "Tab",
      windowsVirtualKeyCode: 9,
    });
    await cdp.send("Input.dispatchKeyEvent", {
      type: "keyUp",
      key: "Tab",
      code: "Tab",
      windowsVirtualKeyCode: 9,
    });
    const trapForward = await cdp.evaluate(
      `document.activeElement === document.querySelector("#mobileMenu .mobile-link")`,
    );
    check(trapForward, "Tab cycles from the close button to the first menu link");

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
    const curtainRunning = await cdp.evaluate(`(() => ({
      state: window.AgentDockCurtain?.state,
      mainInert: document.getElementById("main").hasAttribute("inert"),
      footerInert: document.querySelector("footer").hasAttribute("inert"),
    }))()`);
    check(
      curtainRunning.state === "running" && curtainRunning.mainInert && curtainRunning.footerInert,
      "running curtain temporarily inerts main and footer",
    );
    for (let attempt = 0; attempt < 100; attempt += 1) {
      const curtainDone = await cdp.evaluate(
        `["complete", "skipped"].includes(window.AgentDockCurtain?.state)`,
      );
      if (curtainDone) break;
      await sleep(50);
    }
    const curtainComplete = await cdp.evaluate(`(() => ({
      state: window.AgentDockCurtain?.state,
      mainInert: document.getElementById("main").hasAttribute("inert"),
      footerInert: document.querySelector("footer").hasAttribute("inert"),
    }))()`);
    check(
      ["complete", "skipped"].includes(curtainComplete.state) &&
        !curtainComplete.mainInert &&
        !curtainComplete.footerInert,
      "completed curtain releases main and footer inert ownership",
    );
    const languageAndCapability = await cdp.evaluate(`(() => {
      const [en, zh] = document.querySelectorAll("[data-lang]");
      const panels = Array.from(document.querySelectorAll(".capability-panel"));
      panels[0].focus({ preventScroll: true });
      panels[0].dispatchEvent(new FocusEvent("focusin", { bubbles: true }));
      const focusState = panels.map((panel) => panel.getAttribute("aria-expanded"));
      const focusSucceeded = document.activeElement === panels[0];
      panels[1].click();
      const clickState = panels.map((panel) => panel.getAttribute("aria-expanded"));
      panels[1].dispatchEvent(
        new KeyboardEvent("keydown", { key: " ", bubbles: true, cancelable: true }),
      );
      const keyboardState = panels.map((panel) => panel.getAttribute("aria-expanded"));
      zh.click();
      return {
        focusState,
        clickState,
        keyboardState,
        focusSucceeded,
        title: document.title,
        description: document.querySelector('meta[name="description"]').content,
        lang: document.documentElement.lang,
        enPressed: en.getAttribute("aria-pressed"),
        zhPressed: zh.getAttribute("aria-pressed"),
      };
    })()`);
    check(
      languageAndCapability.focusState.join(",") === "true,false,false,false",
      `capability focus synchronizes its expanded ARIA state (${languageAndCapability.focusState.join(",")}, focused=${languageAndCapability.focusSucceeded})`,
    );
    check(
      languageAndCapability.clickState.join(",") === "false,true,false,false" &&
        languageAndCapability.keyboardState.join(",") === "false,true,false,false",
      "capability click and keyboard states stay synchronized",
    );
    check(
      languageAndCapability.lang === "zh-CN" &&
        languageAndCapability.title === "AgentDock｜一眼掌握所有 AI Agent" &&
        languageAndCapability.description === "AgentDock 将实时 Agent 状态、审批和用量集中呈现在你的 macOS 刘海中。" &&
        languageAndCapability.enPressed === "false" &&
        languageAndCapability.zhPressed === "true",
      "language selection updates localized document metadata",
    );
    const journeyFocusCases = await cdp.evaluate(`(async () => {
      const viewport = document.getElementById("journeyViewport");
      const panels = Array.from(document.querySelectorAll(".journey-panel"));
      panels.forEach((panel) => panel.setAttribute("tabindex", "-1"));
      const trigger = window.ScrollTrigger.getAll().find(
        (candidate) => candidate.trigger === viewport,
      );
      const frame = () => new Promise(requestAnimationFrame);
      const runCase = async (name, originProgress, panelIndex, targetSelector = null) => {
        trigger.refresh();
        const start = trigger.start;
        const end = trigger.end;
        window.scrollTo({ top: start + (end - start) * originProgress, behavior: "instant" });
        await frame();
        document.querySelector("[data-lang='en']").focus({ preventScroll: true });
        const target = targetSelector
          ? panels[panelIndex].querySelector(targetSelector)
          : panels[panelIndex];
        target.focus({ preventScroll: true });
        target.dispatchEvent(new FocusEvent("focusin", { bubbles: true }));
        await frame();
        await frame();
        await frame();
        const targetRect = target.getBoundingClientRect();
        const viewportRect = viewport.getBoundingClientRect();
        return {
          name,
          start,
          end,
          scrollY: window.scrollY,
          targetLeft: targetRect.left,
          targetRight: targetRect.right,
          viewportLeft: viewportRect.left,
          viewportRight: viewportRect.right,
          focused: document.activeElement === target,
        };
      };
      return [
        await runCase("first-at-start", 0, 0),
        await runCase("last-from-start", 0, panels.length - 1),
        await runCase("first-from-end", 1, 0),
        await runCase("middle-forward", 0.34, 2),
        await runCase("middle-backward", 0.67, 1, ".approval-btn"),
        await runCase("last-at-end", 1, panels.length - 1),
      ];
    })()`);
    journeyFocusCases.forEach((result) => {
      check(
        result.focused &&
          result.scrollY >= result.start - 1 &&
          result.scrollY <= result.end + 1 &&
          result.targetLeft >= result.viewportLeft - 1 &&
          result.targetRight <= result.viewportRight + 1,
        `journey ${result.name} stays in refreshed pin range with horizontal focus visibility (focused=${result.focused}, scroll=${result.scrollY}, range=${result.start}-${result.end}, target=${result.targetLeft}-${result.targetRight}, viewport=${result.viewportLeft}-${result.viewportRight})`,
      );
    });

    await setViewport(cdp, 1280, 900);
    await sleep(350);
    const journeyAfterResize = await cdp.evaluate(`(async () => {
      const viewport = document.getElementById("journeyViewport");
      const panels = Array.from(document.querySelectorAll(".journey-panel"));
      panels.forEach((panel) => panel.setAttribute("tabindex", "-1"));
      const frame = () => new Promise(requestAnimationFrame);
      const trigger = window.ScrollTrigger.getAll().find(
        (candidate) => candidate.trigger === viewport,
      );
      trigger.refresh();
      const start = trigger.start;
      const end = trigger.end;
      window.scrollTo({ top: end, behavior: "instant" });
      await frame();
      document.querySelector("[data-lang='en']").focus({ preventScroll: true });
      panels[0].focus({ preventScroll: true });
      panels[0].dispatchEvent(new FocusEvent("focusin", { bubbles: true }));
      await frame();
      await frame();
      await frame();
      const targetRect = panels[0].getBoundingClientRect();
      const viewportRect = viewport.getBoundingClientRect();
      return {
        start,
        end,
        scrollY: window.scrollY,
        targetLeft: targetRect.left,
        targetRight: targetRect.right,
        viewportLeft: viewportRect.left,
        viewportRight: viewportRect.right,
        focused: document.activeElement === panels[0],
      };
    })()`);
    check(
      journeyAfterResize.focused &&
        journeyAfterResize.scrollY >= journeyAfterResize.start - 1 &&
        journeyAfterResize.scrollY <= journeyAfterResize.end + 1 &&
        journeyAfterResize.targetLeft >= journeyAfterResize.viewportLeft - 1 &&
        journeyAfterResize.targetRight <= journeyAfterResize.viewportRight + 1,
      "journey focus uses rebuilt pin geometry after resize",
    );
    await setViewport(cdp, 1440, 1000);
    await sleep(350);
    await cdp.evaluate(`(async () => {
      const section = document.getElementById("context");
      window.scrollTo({
        top: section.getBoundingClientRect().top + window.scrollY,
        left: 0,
        behavior: "instant",
      });
      await new Promise(requestAnimationFrame);
      window.scrollBy({ top: section.getBoundingClientRect().top, behavior: "instant" });
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
    await cdp.evaluate(`(async () => {
      const section = document.getElementById("context");
      window.scrollTo({
        top: section.getBoundingClientRect().top + window.scrollY,
        left: 0,
        behavior: "instant",
      });
      await new Promise(requestAnimationFrame);
      window.scrollBy({ top: section.getBoundingClientRect().top, behavior: "instant" });
    })()`);
    for (let attempt = 0; attempt < 100; attempt += 1) {
      if (await cdp.evaluate("Boolean(window.AgentDockContext?.ready)")) break;
      await sleep(50);
    }
    const constrainedCount = await cdp.evaluate("window.AgentDockContext?.config?.count");
    check(constrainedCount === 1600, "saveData and low-memory context tier uses 1600 particles");

    await cdp.send("Page.addScriptToEvaluateOnNewDocument", {
      source: `(() => {
        const nativeRAF = window.requestAnimationFrame.bind(window);
        let failed = false;
        window.requestAnimationFrame = (callback) => {
          if (!failed && document.getElementById("introCurtain")) {
            failed = true;
            throw new Error("forced curtain animation failure");
          }
          return nativeRAF(callback);
        };
      })();`,
    });
    await load(cdp, `${url}?curtain-error`);
    await sleep(1200);
    const curtainError = await cdp.evaluate(`(() => ({
      state: window.AgentDockCurtain?.state,
      mainInert: document.getElementById("main").hasAttribute("inert"),
      footerInert: document.querySelector("footer").hasAttribute("inert"),
      journeyPinned: document.getElementById("journey").classList.contains("is-pinned"),
      triggerReady: window.ScrollTrigger.getAll().some(
        (trigger) => trigger.trigger === document.getElementById("journeyViewport"),
      ),
    }))()`);
    check(
      curtainError.state === "error" &&
        !curtainError.mainInert &&
        !curtainError.footerInert &&
        curtainError.journeyPinned &&
        curtainError.triggerReady,
      "curtain error releases inert and initializes chapter motion",
    );

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
