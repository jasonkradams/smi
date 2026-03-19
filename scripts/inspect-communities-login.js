const { chromium } = require("playwright");

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 }
  });
  const page = await context.newPage();

  const consoleLogs = [];
  const consoleErrors = [];
  page.on("console", (msg) => {
    const text = msg.text();
    const type = msg.type();
    if (type === "error") consoleErrors.push(text);
    else consoleLogs.push(`[${type}] ${text}`);
  });

  await page.goto("https://www.spokanemountaineers.org/s/CommunitiesLogin", {
    waitUntil: "networkidle",
    timeout: 30000
  });

  await page.waitForTimeout(3000);

  const iframes = await page.evaluate(() => {
    const frames = document.querySelectorAll("iframe");
    return Array.from(frames).map((f) => ({
      id: f.id,
      src: f.src ? f.src.substring(0, 120) : "",
      height: f.style.height || f.getAttribute("height"),
      hasApex: (f.src || "").includes("/apex/")
    }));
  });

  await page.screenshot({
    path: "scripts/communities-login-screenshot.png",
    fullPage: true
  });

  console.log("--- IFRAMES ---");
  console.log(JSON.stringify(iframes, null, 2));

  console.log("\n--- CONSOLE LOGS (last 30) ---");
  consoleLogs.slice(-30).forEach((l) => console.log(l));

  console.log("\n--- CONSOLE ERRORS ---");
  consoleErrors.forEach((e) => console.log(e));

  await browser.close();
})();
