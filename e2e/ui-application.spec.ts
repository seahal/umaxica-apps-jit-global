import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

import { authSurfaceUrl, baseSurfaceUrl } from "../playwright.config";

// Actual anonymous Rails journeys. Authenticated ceremonies are not represented by these roots.
const surfaceUrls = { base: baseSurfaceUrl, auth: authSurfaceUrl };

for (const surface of ["base", "auth"] as const) {
  for (const language of ["ja", "en"] as const) {
    for (const width of [320, 1440]) {
      test(`${surface} anonymous entry in ${language} at ${width}px`, async ({ page }) => {
        await page.setViewportSize({ width, height: 900 });
        await page.route("**/*", (route) => {
          const host = new URL(route.request().url()).hostname;
          // External assets/IdPs are blocked in this isolated test journey.
          // oxlint-disable-next-line vitest/no-conditional-in-test
          return host.endsWith(".localhost") ? route.continue() : route.abort();
        });
        const url = new URL(surfaceUrls[surface]());
        url.searchParams.set("ri", "jp");
        url.searchParams.set("lx", language);
        const response = await page.goto(url.toString());
        expect(response?.status()).toBe(200);
        await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
          width,
        );
        await page.keyboard.press("Tab");
        await expect(page.locator(".ui-skip-link")).toBeFocused();
        await page.keyboard.press("Enter");
        await expect(page.getByRole("main")).toBeFocused();
        const audit = await new AxeBuilder({ page })
          .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
          .analyze();
        expect(audit.violations).toEqual([]);
        const cookie = page.locator("#cookie-banner");
        await expect(cookie).toHaveCount(1);
        expect(await cookie.evaluate((node) => getComputedStyle(node).position)).toBe("static");
      });
    }
  }
}

test("the existing neutral sign-entry form retains its POST contract and readable submit target", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.route("**/*", (route) => {
    // oxlint-disable-next-line vitest/no-conditional-in-test
    return new URL(route.request().url()).hostname.endsWith(".localhost")
      ? route.continue()
      : route.abort();
  });
  const url = new URL("/sign?ri=jp&lx=en", baseSurfaceUrl());
  expect((await page.goto(url.toString()))?.status()).toBe(200);
  const form = page.locator("main form");
  await expect(form).toHaveAttribute("method", "post");
  const submit = form.locator('input[type="submit"]');
  await expect(submit).toHaveAccessibleName("Continue");
  expect((await submit.boundingBox())?.height).toBeGreaterThanOrEqual(44);
  expect(
    (
      await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
        .analyze()
    ).violations,
  ).toEqual([]);
});

test("offline recovery preserves its native retry without an application runtime", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  const url = new URL("/offline", baseSurfaceUrl());
  expect((await page.goto(url.toString()))?.status()).toBe(200);
  await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();
  await expect(page.getByRole("form")).toHaveAttribute("method", "get");
  await expect(page.getByRole("button")).toHaveAttribute("type", "submit");
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
  expect(
    (
      await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
        .analyze()
    ).violations,
  ).toEqual([]);
});
