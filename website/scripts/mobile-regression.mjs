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
  if (!condition) throw new Error(message);
}

try {
  const page = await browser.newPage();
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  page.on("pageerror", (error) => errors.push(error.message));

  await page.setViewport(viewport);
  await page.goto(targetUrl, { waitUntil: "networkidle0", timeout: 30_000 });
  await page.waitForSelector("#hero-title");

  const baseline = await page.evaluate(() => {
    const title = document.querySelector("#hero-title");
    const menuButton = document.querySelector(
      "button[data-mobile-menu-button]",
    );
    const hero = document.querySelector("#top");
    const dotLayer = hero?.querySelector("div");
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
      scrollHeight: document.documentElement.scrollHeight,
      heroHeight: hero?.getBoundingClientRect().height ?? 0,
      heroLines,
      sectionCount: document.querySelectorAll("main > section").length,
      footerCount: document.querySelectorAll("footer").length,
      hasCanvas: Boolean(hero?.querySelector("canvas")),
      hasDotTexture:
        dotLayer instanceof HTMLElement &&
        getComputedStyle(dotLayer).backgroundImage.includes("hero-dot-grid.png"),
      menu: {
        id: document.querySelector("#site-menu")?.id,
        ariaModal: document.querySelector("#site-menu")?.getAttribute("aria-modal"),
        label: document.querySelector("#site-menu")?.getAttribute("aria-label"),
        buttonTarget: menuButton?.getAttribute("aria-controls"),
        rect: menuButton?.getBoundingClientRect().toJSON(),
      },
    };
  });

  assert(
    baseline.scrollWidth === viewport.width,
    `Expected scrollWidth ${viewport.width}, received ${baseline.scrollWidth}`,
  );
  assert(
    baseline.scrollHeight === viewport.height &&
      baseline.heroHeight === viewport.height,
    `Homepage must fit exactly one mobile viewport: ${JSON.stringify(baseline)}`,
  );
  assert(
    baseline.sectionCount === 1 && baseline.footerCount === 0,
    `Only the hero section may remain: ${JSON.stringify(baseline)}`,
  );
  assert(
    baseline.hasCanvas && baseline.hasDotTexture,
    "Hero must render both the particle canvas and dotted black texture",
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

  await page.click("button[data-mobile-menu-button]");
  await page.waitForFunction(
    () => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "false",
  );
  await page.waitForFunction(
    () => Boolean(document.activeElement?.closest("#site-menu")),
  );

  const menuState = await page.evaluate(() => ({
    expanded: document
      .querySelector("[data-mobile-menu-button]")
      ?.getAttribute("aria-expanded"),
    focused: Boolean(document.activeElement?.closest("#site-menu")),
    links: document.querySelectorAll("#site-menu a").length,
    undersized: [
      ...document.querySelectorAll(
        "#site-menu a, button[data-mobile-menu-button]",
      ),
    ]
      .map((element) => ({
        label: element.textContent?.trim() || element.getAttribute("aria-label"),
        height: element.getBoundingClientRect().height,
      }))
      .filter((target) => target.height < 44),
  }));
  assert(
    menuState.expanded === "true" && menuState.focused && menuState.links === 5,
    `Mobile menu did not open correctly: ${JSON.stringify(menuState)}`,
  );
  assert(
    menuState.undersized.length === 0,
    `Touch targets under 44px: ${JSON.stringify(menuState.undersized)}`,
  );

  await page.keyboard.press("Escape");
  await page.waitForFunction(
    () => document.querySelector("#site-menu")?.getAttribute("aria-hidden") === "true",
  );

  const initialLanguage = await page.evaluate(
    () => document.documentElement.lang,
  );
  await page.click("button[aria-label^='Switch to']");
  const toggledLanguage = await page.evaluate(
    () => document.documentElement.lang,
  );
  assert(
    new Set([initialLanguage, toggledLanguage]).size === 2,
    "Language toggle must switch the document language",
  );
  assert(errors.length === 0, `Console errors: ${errors.join("; ")}`);

  console.log(
    JSON.stringify(
      {
        viewport: `${viewport.width}x${viewport.height}`,
        oneScreen: true,
        dottedTexture: baseline.hasDotTexture,
        menuLinks: menuState.links,
      },
      null,
      2,
    ),
  );
} finally {
  await browser.close();
}
