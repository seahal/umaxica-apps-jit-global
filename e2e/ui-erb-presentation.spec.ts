import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Actual ActionView output with the independent Propshaft stylesheet injected.
// This is an anonymous renderer fixture, not an authenticated app-route or CSP-delivery test.
let renderedHtml: string;
const stylesheet = readFileSync("app/assets/stylesheets/application.css", "utf8");

test.beforeAll(() => {
  renderedHtml = execFileSync(
    "bin/rails",
    [
      "runner",
      "-e",
      "test",
      'STDOUT.write(Auth::App::Sign::OutsController.renderer.new(http_host: "auth.app.localhost", https: false).render(template: "auth/shared/sign_outs/edit", layout: "auth/app/application"))',
    ],
    { encoding: "utf8", timeout: 30_000 },
  );
});

for (const width of [320, 768, 1024, 1440]) {
  for (const theme of ["light", "dark", "system"] as const) {
    test(`ERB confirmation reflows at ${width}px in ${theme}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ colorScheme: "dark", reducedMotion: "reduce" });
      await page.route("**/*", (route) => route.abort());
      await page.setContent(renderedHtml);
      await page.addStyleTag({ content: stylesheet });
      await page.locator("html").evaluate((node, value) => (node.dataset["theme"] = value), theme);
      await page.evaluate(
        () =>
          new Promise<void>((resolve) => {
            requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
          }),
      );
      await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
        width,
      );
      const close = page.locator(".ui-cookie__close");
      const size = await close.boundingBox();
      expect(size?.width).toBeGreaterThanOrEqual(44);
      expect(size?.width).toBeLessThanOrEqual(48);
      expect(size?.height).toBeGreaterThanOrEqual(44);
      for (const control of [close, page.locator(".ui-button--secondary").first()]) {
        expect(await control.evaluate((node) => getComputedStyle(node).backgroundColor)).toBe(
          await page.locator("footer").evaluate((node) => getComputedStyle(node).backgroundColor),
        );
      }
      const audit = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
        .analyze();
      expect(audit.violations).toEqual([]);
    });
  }
}
