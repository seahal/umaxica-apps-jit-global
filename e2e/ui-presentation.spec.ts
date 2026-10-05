import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Component browser coverage, explicitly separate from application route coverage.
// Start: node node_modules/vite/bin/vite.js --config e2e/presentation.vite.config.ts
const fixtureUrl = "http://127.0.0.1:3190/";

for (const width of [320, 768, 1024, 1440]) {
  for (const theme of ["light", "dark", "system"] as const) {
    test(`primitives reflow at ${width}px in ${theme} mode`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
      await page.goto(fixtureUrl);
      await expect(page.getByRole("heading", { name: "UI primitives", exact: true })).toBeVisible();
      await page.locator("html").evaluate((node, value) => (node.dataset["theme"] = value), theme);
      await page.evaluate(
        () =>
          new Promise<void>((resolve) => {
            requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
          }),
      );
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
        width,
      );
      const button = page.getByRole("button", { name: "primary", exact: true });
      const metrics = await button.evaluate((node) => ({
        width: node.getBoundingClientRect().width,
        height: node.getBoundingClientRect().height,
        font: getComputedStyle(node).fontSize,
      }));
      expect(metrics.width).toBeGreaterThanOrEqual(44);
      expect(metrics.height).toBeGreaterThanOrEqual(44);
      expect(metrics.font).toBe("16px");
      expect(
        await page
          .getByRole("link", { name: "inline link", exact: true })
          .evaluate((node) => getComputedStyle(node).textDecorationLine),
      ).toContain("underline");
      const audit = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
        .analyze();
      expect(audit.violations).toEqual([]);
    });
  }
}

test("checkbox label participates in its target and native form state", async ({ page }) => {
  await page.goto(fixtureUrl);
  const checkbox = page.getByRole("checkbox", { name: "Performance cookies" });
  const label = page.locator("label").filter({ has: checkbox });
  expect((await label.boundingBox())?.height).toBeGreaterThanOrEqual(44);
  await label.click();
  await expect(checkbox).toBeChecked();
});

test("dialog traps keyboard focus and returns it on Escape", async ({ page }) => {
  await page.goto(fixtureUrl);
  const trigger = page.getByRole("button", { name: "Open the dialog" });
  await trigger.click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  await page.keyboard.press("Tab");
  expect(await dialog.evaluate((node) => node.contains(document.activeElement))).toBe(true);
  await page.keyboard.press("Escape");
  await expect(dialog).not.toBeVisible();
  await expect(trigger).toBeFocused();
});

test("long text and 200 percent text sizing reflow at 320px", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto(fixtureUrl);
  await page.getByRole("heading", { name: "UI primitives", exact: true }).evaluate((node) => {
    node.textContent = "日本語の長い見出しとABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    document.documentElement.lang = "ja";
    document.documentElement.style.fontSize = "200%";
  });
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
});
