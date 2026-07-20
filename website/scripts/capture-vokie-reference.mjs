import { mkdir } from "node:fs/promises";
import path from "node:path";
import puppeteer from "puppeteer-core";

const chromePath =
  process.env.CHROME_PATH ??
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const targetUrl = "https://vokie.com/";
const outputDir = path.resolve("docs/design-references/vokie");

await mkdir(outputDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--no-first-run", "--disable-background-networking"],
});

async function preparePage(viewport) {
  const page = await browser.newPage();
  await page.setViewport(viewport);
  await page.emulateMediaFeatures([
    { name: "prefers-reduced-motion", value: "no-preference" },
  ]);
  await page.goto(targetUrl, { waitUntil: "networkidle2", timeout: 30_000 });
  await new Promise((resolve) => setTimeout(resolve, 2_600));
  return page;
}

try {
  const desktop = await preparePage({
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
  });
  await desktop.screenshot({
    path: path.join(outputDir, "vokie-desktop-1440.png"),
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
    path: path.join(outputDir, "vokie-mobile-390.png"),
    fullPage: true,
  });
  await mobile.click("#menu-toggle");
  await new Promise((resolve) => setTimeout(resolve, 500));
  await mobile.screenshot({
    path: path.join(outputDir, "vokie-mobile-menu-390.png"),
    fullPage: false,
  });
  await mobile.close();
} finally {
  await browser.close();
}

console.log(`Saved Vokie references to ${outputDir}`);
