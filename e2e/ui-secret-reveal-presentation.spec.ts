import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Isolated Rails renderer with visibly synthetic values. No issuance is requested or admitted.
let html = "";
let stylesheet = "";
test.beforeAll(() => {
  html = execFileSync(
    "bin/rails",
    [
      "runner",
      "-e",
      "test",
      `abort 'test required' unless Rails.env.test?
I18n.locale = :en
STDOUT.write(Base::App::SecretPresentationsController.renderer.render(template: 'base/app/secret_presentations/create', layout: false, assigns: {issuance: Struct.new(:origin, :planned_count).new('synthetic', 1), values: ['SYNTHETIC-DISPLAY-VALUE-ONLY-123456']}, locals: {confirmation_url: '/synthetic/confirm', cancel_url: '/synthetic/cancel', checkpoint_version: 7}))`,
    ],
    { encoding: "utf8" },
  );
  const href = html.match(/href="(\/vite-test\/assets\/[A-Za-z0-9_-]+\.css)"/u)?.[1];
  if (!href) {
    throw new Error("The reveal fixture has no own-stack stylesheet.");
  }
  stylesheet = readFileSync(`public${href}`, "utf8");
});

for (const width of [320, 768, 1024, 1440]) {
  test(`one-time reveal display preserves readable acknowledgement and cancellation at ${width}px`, async ({
    page,
  }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.route("**/*", (route) => route.abort());
    await page.setContent(html);
    await page.addStyleTag({ content: stylesheet });
    await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();
    const stored = page.getByRole("checkbox");
    const label = page.locator(`label[for="${await stored.getAttribute("id")}"]`);
    expect((await label.boundingBox())?.height).toBeGreaterThanOrEqual(44);
    await label.click();
    await expect(stored).toBeChecked();
    for (const submit of await page.locator('input[type="submit"]').all()) {
      expect((await submit.boundingBox())?.height).toBeGreaterThanOrEqual(44);
      await submit.focus();
      await expect(submit).toBeFocused();
    }
    await expect(
      page.locator('form[action="/synthetic/confirm"] input[name="_method"]'),
    ).toHaveValue("patch");
    await expect(
      page.locator('form[action="/synthetic/cancel"] input[name="_method"]'),
    ).toHaveValue("delete");
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
      width,
    );
    expect(
      (
        await new AxeBuilder({ page })
          .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
          .analyze()
      ).violations,
    ).toEqual([]);
    await page.screenshot({
      path: `/tmp/umaxica-ui-normalization-continuation/secret-reveal-synthetic-${width}.png`,
      fullPage: true,
    });
  });
}
