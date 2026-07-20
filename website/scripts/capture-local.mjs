import { mkdir } from "node:fs/promises";
import path from "node:path";
import puppeteer from "puppeteer-core";

const chromePath =
  process.env.CHROME_PATH ??
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const targetUrl = process.env.LOCAL_URL ?? "http://127.0.0.1:3000/";
const outputDir = path.resolve("docs/design-references/local");

await mkdir(outputDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--no-first-run", "--disable-background-networking"],
});

async function preparePage(viewport) {
  const page = await browser.newPage();
  await page.setViewport(viewport);
  await page.goto(targetUrl, { waitUntil: "networkidle0", timeout: 30_000 });
  await new Promise((resolve) => setTimeout(resolve, 2_600));
  return page;
}

async function assertMobileAccessibility(page) {
  const results = await page.evaluate(() => {
    const menuButton = document.querySelector(
      "button[data-mobile-menu-button]",
    );
    const tabList = document.querySelector('[role="tablist"]');
    const heroTitle = document.querySelector("#hero-title");

    return {
      pageWidth: document.documentElement.scrollWidth,
      hasMenuButton: menuButton !== null,
      heroLineCounts: [...(heroTitle?.querySelectorAll("span") ?? [])].map(
        (line) => line.getClientRects().length,
      ),
      tabListOverflow:
        tabList instanceof HTMLElement && tabList.scrollWidth > tabList.clientWidth,
    };
  });

  if (results.pageWidth !== 390) {
    throw new Error(`Expected a 390px document, received ${results.pageWidth}px`);
  }
  if (!results.hasMenuButton) {
    throw new Error("Mobile menu button must expose data-mobile-menu-button");
  }
  if (results.heroLineCounts.some((count) => count !== 1)) {
    throw new Error(
      `Hero title must keep each localized phrase on one line: ${results.heroLineCounts.join(", ")}`,
    );
  }
  if (!results.tabListOverflow) {
    throw new Error("Mobile voice tabs must reveal additional scrollable tabs");
  }
}

async function assertDesktopQuantitativeLayout(page) {
  const measurements = await page.evaluate(async () => {
    document.documentElement.style.scrollBehavior = "auto";
    const waitForTransition = () =>
      new Promise((resolve) => window.setTimeout(resolve, 300));
    const getRect = (element) => {
      const { bottom, height, left, right, top, width } =
        element.getBoundingClientRect();
      return { bottom, height, left, right, top, width };
    };
    const header = document.querySelector("header");
    const headerInner = header?.querySelector("div");
    const privacy = document.querySelector("#privacy");
    const privacyInner = privacy?.querySelector(":scope > div");
    const privacyCard = privacyInner?.querySelector(":scope > div");
    const privacyVisual = privacyInner?.querySelector(":scope > figure");
    const finalCta = document.querySelector("#download");
    const finalCtaInner = finalCta?.querySelector(":scope > div");
    const finalCtaVisual = finalCtaInner?.querySelector(":scope > div");
    const finalCtaCard = finalCtaInner?.querySelector(":scope > :last-child");

    window.scrollTo(0, window.innerHeight * 0.45);
    window.dispatchEvent(new Event("scroll"));
    await waitForTransition();
    const scrolledInnerStyles = headerInner ? getComputedStyle(headerInner) : null;

    window.scrollTo(0, window.innerHeight * 1.5);
    window.dispatchEvent(new Event("scroll"));
    await waitForTransition();
    const hiddenStyles = header ? getComputedStyle(header) : null;

    return {
      header: {
        background: scrolledInnerStyles?.backgroundColor,
        border: scrolledInnerStyles?.borderColor,
        blur: scrolledInnerStyles?.backdropFilter,
        hiddenTransform: hiddenStyles?.transform,
        innerTransform: scrolledInnerStyles?.transform,
      },
      privacy: {
        background: privacy ? getComputedStyle(privacy).backgroundColor : null,
        paddingTop: privacy ? getComputedStyle(privacy).paddingTop : null,
        paddingBottom: privacy ? getComputedStyle(privacy).paddingBottom : null,
        columns: privacyInner
          ? getComputedStyle(privacyInner).gridTemplateColumns
          : null,
        gap: privacyInner ? getComputedStyle(privacyInner).gap : null,
        inner: privacyInner ? getRect(privacyInner) : null,
        card: privacyCard ? getRect(privacyCard) : null,
        visual: privacyVisual ? getRect(privacyVisual) : null,
      },
      finalCta: {
        directChildren: finalCtaInner?.children.length ?? 0,
        columns: finalCtaInner
          ? getComputedStyle(finalCtaInner).gridTemplateColumns
          : null,
        visual: finalCtaVisual ? getRect(finalCtaVisual) : null,
        card: finalCtaCard ? getRect(finalCtaCard) : null,
      },
    };
  });

  const closeTo = (actual, expected, tolerance, label) => {
    if (Math.abs(actual - expected) > tolerance) {
      throw new Error(`${label}: expected ${expected}±${tolerance}, received ${actual}`);
    }
  };

  if (
    measurements.header.background === "rgba(0, 0, 0, 0)" ||
    measurements.header.border === "rgba(0, 0, 0, 0)"
  ) {
    throw new Error(
      `Scrolled header surface is missing: ${JSON.stringify(measurements.header)}`,
    );
  }
  if (
    measurements.header.hiddenTransform === "none" ||
    !measurements.header.hiddenTransform?.includes("-")
  ) {
    throw new Error(
      `Hidden header must translate the outer header: ${JSON.stringify(measurements.header)}`,
    );
  }
  if (
    measurements.privacy.background !== "rgb(17, 17, 17)" ||
    measurements.privacy.paddingTop !== "112px" ||
    measurements.privacy.paddingBottom !== "64px" ||
    measurements.privacy.gap !== "28px" ||
    measurements.privacy.inner === null ||
    measurements.privacy.card === null ||
    measurements.privacy.visual === null
  ) {
    throw new Error(`Privacy wrapper mismatch: ${JSON.stringify(measurements.privacy)}`);
  }
  closeTo(measurements.privacy.inner.width, 1360, 1, "Privacy inner width");
  if (
    measurements.privacy.card.left >= measurements.privacy.inner.left ||
    measurements.privacy.visual.left <= measurements.privacy.card.right
  ) {
    throw new Error(`Privacy grid/bleed mismatch: ${JSON.stringify(measurements.privacy)}`);
  }
  if (
    measurements.finalCta.directChildren !== 2 ||
    measurements.finalCta.visual === null
  ) {
    throw new Error(`CTA direct grid assembly mismatch: ${JSON.stringify(measurements.finalCta)}`);
  }
  if (measurements.finalCta.visual.width < 540) {
    throw new Error(`CTA dimensions/bleed mismatch: ${JSON.stringify(measurements.finalCta)}`);
  }

  console.log("Desktop quantitative measurements:", JSON.stringify(measurements));
}

try {
  const desktop = await preparePage({
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
  });
  await assertDesktopQuantitativeLayout(desktop);
  await desktop.screenshot({
    path: path.join(outputDir, "agentdock-desktop-1440.png"),
    fullPage: true,
  });
  await desktop.close();

  const mobile = await preparePage({
    width: 390,
    height: 844,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  });
  await mobile.screenshot({
    path: path.join(outputDir, "agentdock-mobile-390.png"),
    fullPage: true,
  });
  await assertMobileAccessibility(mobile);
  await mobile.click("button[aria-controls='site-menu']");
  await new Promise((resolve) => setTimeout(resolve, 500));
  await mobile.screenshot({
    path: path.join(outputDir, "agentdock-mobile-menu-390.png"),
    fullPage: false,
  });
  await mobile.close();
} finally {
  await browser.close();
}

console.log(`Saved AgentDock captures to ${outputDir}`);
