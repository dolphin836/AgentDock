import puppeteer from "puppeteer-core";

const chromePath =
  process.env.CHROME_PATH ??
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const targetUrl = process.env.LOCAL_URL ?? "http://127.0.0.1:3000/";
const viewport = {
  width: 390,
  height: 844,
  deviceScaleFactor: 1,
  isMobile: true,
  hasTouch: true,
};

const browser = await puppeteer.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--no-sandbox", "--no-first-run", "--disable-background-networking"],
});

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

try {
  const page = await browser.newPage();
  await page.setViewport(viewport);
  await page.goto(targetUrl, { waitUntil: "networkidle0", timeout: 30_000 });
  await page.waitForSelector("#hero-title");

  const baseline = await page.evaluate(() => {
    const title = document.querySelector("#hero-title");
    const tabList = document.querySelector('[role="tablist"]');
    const tabs = [...document.querySelectorAll('[role="tab"]')];
    const menuButton = document.querySelector(
      "button[data-mobile-menu-button]",
    );

    const heroLines = [...(title?.querySelectorAll("span") ?? [])].map(
      (line) => {
        const range = document.createRange();
        range.selectNodeContents(line);
        return {
          rects: range.getClientRects().length,
          text: line.textContent?.trim() ?? "",
        };
      },
    );

    return {
      scrollWidth: document.documentElement.scrollWidth,
      heroLines,
      menu: {
        id: document.querySelector("#site-menu")?.id,
        ariaModal: document.querySelector("#site-menu")?.getAttribute("aria-modal"),
        label: document.querySelector("#site-menu")?.getAttribute("aria-label"),
        buttonTarget: menuButton?.getAttribute("aria-controls"),
        rect: menuButton?.getBoundingClientRect().toJSON(),
      },
      tabs: {
        count: tabs.length,
        tabIndexes: tabs.map((tab) => tab.getAttribute("tabindex")),
        selected: tabs.map((tab) => tab.getAttribute("aria-selected")),
        controls: tabs.map((tab) => tab.getAttribute("aria-controls")),
        controlsValid: tabs.every((tab) => {
          const controlsId = tab.getAttribute("aria-controls");
          return (
            controlsId !== null &&
            document.getElementById(controlsId)?.getAttribute("role") === "tabpanel"
          );
        }),
        scrollWidth: tabList?.scrollWidth ?? 0,
        clientWidth: tabList?.clientWidth ?? 0,
        scrollSnapType: tabList ? getComputedStyle(tabList).scrollSnapType : "",
        maskImage: tabList ? getComputedStyle(tabList).maskImage : "",
      },
    };
  });

  assert(
    baseline.scrollWidth === viewport.width,
    `Expected scrollWidth ${viewport.width}, received ${baseline.scrollWidth}`,
  );
  assert(
    baseline.heroLines.every((line) => line.rects === 1 && line.text.length > 1),
    `Hero phrases must each occupy one line: ${JSON.stringify(baseline.heroLines)}`,
  );
  assert(
    baseline.menu.id === "site-menu" &&
      baseline.menu.ariaModal === "true" &&
      Boolean(baseline.menu.label) &&
      baseline.menu.buttonTarget === "site-menu" &&
      baseline.menu.rect?.height >= 44,
    `Mobile menu contract failed: ${JSON.stringify(baseline.menu)}`,
  );
  assert(baseline.tabs.count > 1, "Expected multiple voice tabs");
  assert(
    baseline.tabs.scrollWidth > baseline.tabs.clientWidth,
    `Voice tabs must overflow horizontally: ${JSON.stringify(baseline.tabs)}`,
  );
  assert(
    baseline.tabs.scrollSnapType.includes("x"),
    `Voice tabs must use horizontal scroll snap: ${baseline.tabs.scrollSnapType}`,
  );
  assert(
    baseline.tabs.maskImage !== "none",
    "Voice tabs must apply a right-edge fade mask",
  );
  assert(
    baseline.tabs.tabIndexes.filter((value) => value === "0").length === 1 &&
      baseline.tabs.tabIndexes.every(
        (value) => value === "0" || value === "-1",
      ),
    `Voice tabs must use roving tabindex: ${JSON.stringify(baseline.tabs.tabIndexes)}`,
  );
  assert(
    baseline.tabs.selected.filter((value) => value === "true").length === 1 &&
      baseline.tabs.controlsValid,
    `Voice tab ARIA references failed: ${JSON.stringify(baseline.tabs)}`,
  );

  const firstTab = '[role="tab"]:nth-of-type(1)';
  await page.focus(firstTab);
  await page.keyboard.press("ArrowRight");
  const afterRight = await page.evaluate(() => ({
    activeId: document.activeElement?.id,
    selected: document.activeElement?.getAttribute("aria-selected"),
    tabIndex: document.activeElement?.getAttribute("tabindex"),
  }));
  assert(
    afterRight.selected === "true" && afterRight.tabIndex === "0",
    `ArrowRight must move the active roving tab: ${JSON.stringify(afterRight)}`,
  );

  await page.keyboard.press("End");
  const afterEnd = await page.evaluate(() => document.activeElement?.id);
  await page.keyboard.press("Home");
  const afterHome = await page.evaluate(() => ({
    activeId: document.activeElement?.id,
    panelId: document
      .querySelector('[role="tab"][aria-selected="true"]')
      ?.getAttribute("aria-controls"),
    panelLabel: document
      .querySelector('[role="tabpanel"]')
      ?.getAttribute("aria-labelledby"),
  }));
  assert(afterEnd?.includes("return-workspace"), `End did not select last tab: ${afterEnd}`);
  assert(
    afterHome.activeId?.includes("live-status") &&
      afterHome.panelId &&
      afterHome.panelLabel === afterHome.activeId,
    `Home/ARIA linkage failed: ${JSON.stringify(afterHome)}`,
  );

  await page.click("button[data-mobile-menu-button]");
  await page.waitForFunction(
    () => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "false",
  );
  await page.waitForFunction(
    () => Boolean(document.activeElement?.closest("#site-menu")),
  );
  await page.keyboard.down("Shift");
  await page.keyboard.press("Tab");
  await page.keyboard.up("Shift");
  const focusAfterReverseTab = await page.evaluate(() => ({
    isMenuButton: document.activeElement?.matches("[data-mobile-menu-button]"),
  }));
  await page.keyboard.press("Tab");
  const focusAfterForwardTab = await page.evaluate(() => ({
    inMenu: Boolean(document.activeElement?.closest("#site-menu")),
  }));
  assert(
    focusAfterReverseTab.isMenuButton && focusAfterForwardTab.inMenu,
    `Mobile menu focus escaped its trap: ${JSON.stringify({
      focusAfterReverseTab,
      focusAfterForwardTab,
    })}`,
  );

  const touchTargets = await page.evaluate(() =>
    [...document.querySelectorAll(
      "footer a, #meeting button, button[data-mobile-menu-button]",
    )].map((element) => {
      const rect = element.getBoundingClientRect();
      return {
        label: element.textContent?.trim() || element.getAttribute("aria-label"),
        height: rect.height,
      };
    }),
  );
  const undersized = touchTargets.filter((target) => target.height < 44);
  assert(
    undersized.length === 0,
    `Touch targets under 44px: ${JSON.stringify(undersized)}`,
  );

  console.log(
    JSON.stringify(
      {
        viewport: `${viewport.width}x${viewport.height}`,
        scrollWidth: baseline.scrollWidth,
        heroLineRects: baseline.heroLines.map((line) => line.rects),
        voiceTabViewport: `${baseline.tabs.clientWidth}/${baseline.tabs.scrollWidth}`,
        touchTargetCount: touchTargets.length,
        minTouchHeight: Math.min(...touchTargets.map((target) => target.height)),
      },
      null,
      2,
    ),
  );
} finally {
  await browser.close();
}
