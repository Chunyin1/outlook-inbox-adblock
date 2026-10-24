const { test, expect } = require("@playwright/test");
const fs = require("node:fs");
const path = require("node:path");
const script = fs.readFileSync(
  path.join(__dirname, "../src/cosmetic/filter.js"),
  "utf8",
);
const ad =
  '<div class="ad"><img src="https://res.public.onecdn.static.microsoft/owamail/test/ads-olk-icon.png"><span>Upgrade</span></div>';
const html = `<!doctype html><html><head><style>.ad{height:82px}[role=option]{height:50px}</style></head><body><div data-testid="virtuoso-scroller"><div>${ad}<div class="messages"><div role="option">Example message A</div><div role="option">Example message B</div></div></div></div></body></html>`;
async function open(page, url = "https://outlook.office.com/mail/") {
  await page.setViewportSize({ width: 800, height: 600 });
  await page.route("**/*", (route) =>
    route.request().isNavigationRequest()
      ? route.fulfill({ contentType: "text/html", body: html })
      : route.abort(),
  );
  await page.addInitScript({ content: script });
  await page.goto(url);
}
test("preloads before ad insertion, hides the complete card and preserves messages", async ({
  page,
}) => {
  await open(page);
  await expect(page.locator(".ad")).toBeHidden();
  await expect(page.getByRole("option")).toHaveCount(2);
  await expect(page.getByRole("option").first()).toBeVisible();
  const stats = await page.evaluate(() =>
    globalThis.__outlookCosmeticFilter.stats(),
  );
  expect(stats.installedBeforeAd).toBe(true);
  expect(stats.visibleMessageRows).toBe(2);
  expect(stats.visibleAdIcons).toBe(0);
});
test("replacement cards are hidden synchronously, before observer callbacks", async ({
  page,
}) => {
  await open(page);
  const visible = await page.evaluate(() => {
    const first = document.querySelector(".ad");
    let count = 0;
    for (let i = 0; i < 20; i++) {
      const node = first.cloneNode(true);
      node.removeAttribute("data-local-outlook-ad-hidden");
      node
        .querySelectorAll("[data-local-outlook-ad-hidden]")
        .forEach((x) => x.removeAttribute("data-local-outlook-ad-hidden"));
      first.parentElement.prepend(node);
      count += node.getBoundingClientRect().height > 0 ? 1 : 0;
      node.remove();
    }
    return count;
  });
  expect(visible).toBe(0);
});
test("does not hide real message rows even when they contain the same icon", async ({
  page,
}) => {
  await open(page);
  await page.evaluate(() => {
    const row = document.querySelector("[role=option]");
    row.append(document.querySelector(".ad img").cloneNode());
  });
  await expect(page.getByRole("option").first()).toBeVisible();
  expect(
    (await page.evaluate(() => globalThis.__outlookCosmeticFilter.stats()))
      .visibleMessageRows,
  ).toBe(2);
});
test("undo restores ad layout, repeated apply creates one style, reload preloads again", async ({
  page,
}) => {
  await open(page);
  await page.evaluate(() => globalThis.__outlookCosmeticFilter.stop());
  await expect(page.locator(".ad")).toBeVisible();
  await page.evaluate(script);
  await page.evaluate(script);
  await expect(page.locator("#local-outlook-cosmetic-filter")).toHaveCount(1);
  await expect(page.locator(".ad")).toBeHidden();
  await page.reload();
  expect(
    (await page.evaluate(() => globalThis.__outlookCosmeticFilter.stats()))
      .installedBeforeAd,
  ).toBe(true);
  await expect(page.locator(".ad")).toBeHidden();
});
test("does not activate outside allowed Outlook mail origins and paths", async ({
  page,
}) => {
  for (const url of [
    "https://example.test/mail/",
    "https://outlook.office.com/calendar/",
    "https://outlook.office.com.evil.test/mail/",
  ]) {
    await open(page, url);
    expect(
      await page.evaluate(() => !!globalThis.__outlookCosmeticFilter),
    ).toBe(false);
    await expect(page.locator(".ad")).toBeVisible();
  }
});
test("retargeting a hidden container to a real message removes the marker", async ({
  page,
}) => {
  await open(page);
  await page.evaluate(() => {
    const card = document.querySelector(".ad");
    card.innerHTML = '<div role="option">New real message</div>';
  });
  await expect(page.getByRole("option")).toHaveCount(3);
  await expect(page.getByRole("option").first()).toBeVisible();
});

test("a real row directly under the scroller stays visible with the ad icon", async ({
  page,
}) => {
  await open(page);
  await page.evaluate(() => {
    const card = document.querySelector(".ad");
    card.setAttribute("role", "option");
  });
  await expect(page.locator(".ad")).toBeVisible();
  await expect(page.getByRole("option")).toHaveCount(3);
});
