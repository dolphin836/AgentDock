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

async function capture(name, viewport) {
  const page = await browser.newPage();
  await page.setViewport(viewport);
  await page.goto(targetUrl, { waitUntil: "networkidle0", timeout: 30_000 });
  await page.waitForSelector("#hero-title");
  await new Promise((resolve) => setTimeout(resolve, 2_600));

  const contract = await page.evaluate(() => ({
    viewport: { width: innerWidth, height: innerHeight },
    document: {
      width: document.documentElement.scrollWidth,
      height: document.documentElement.scrollHeight,
    },
    sections: document.querySelectorAll("main > section").length,
    footers: document.querySelectorAll("footer").length,
    dots: getComputedStyle(document.querySelector("#top > div")).backgroundImage,
  }));

  if (
    contract.document.width > contract.viewport.width ||
    contract.document.height !== contract.viewport.height ||
    contract.sections !== 1 ||
    contract.footers !== 0 ||
    !contract.dots.includes("hero-dot-grid.png")
  ) {
    throw new Error(`One-screen capture contract failed: ${JSON.stringify(contract)}`);
  }

  await page.screenshot({
    path: path.join(outputDir, name),
    fullPage: false,
  });
  await page.close();
}

try {
  await capture("agentdock-desktop-1440.png", {
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
  });
  await capture("agentdock-mobile-390.png", {
    width: 390,
    height: 844,
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  });
} finally {
  await browser.close();
}

console.log(`Saved one-screen AgentDock captures to ${outputDir}`);
