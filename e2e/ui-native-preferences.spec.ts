import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Actual unauthenticated preference GETs; changing the selection never submits it in this test.
for (const edition of ["app", "com", "org"]) {
  for (const language of ["ja", "en"]) {
    test(`native preference selection retains its Rails payload on ${edition}/${language}`, async ({
      page,
    }) => {
      await page.setViewportSize({ width: 320, height: 900 });
      const host = `base.${edition}.localhost`;
      await page.route("**/*", (route) => {
        // oxlint-disable-next-line vitest/no-conditional-in-test
        return new URL(route.request().url()).hostname === host ? route.continue() : route.abort();
      });
      expect(
        (
          await page.goto(`http://${host}:3188/preference/language/edit?ri=jp&lx=${language}`)
        )?.status(),
      ).toBe(200);
      await expect(page.locator("html")).toHaveAttribute("lang", language);
      await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();
      const select = page.getByRole("combobox");
      await expect(select).toHaveAttribute("name", "preference_language[option_id]");
      await expect(select).toHaveValue("1");
      await expect(select.locator('option[value="1"]')).toBeDisabled();
      await select.selectOption("2");
      await expect(select).toHaveValue("2");
      expect(
        await select.evaluate((node) => {
          // oxlint-disable-next-line vitest/no-conditional-in-test
          if (!(node instanceof HTMLSelectElement) || !node.form) {
            throw new Error("Preference control must belong to its existing form");
          }
          return new FormData(node.form).get(node.name);
        }),
      ).toBe("2");
      const footerName = await page.locator('meta[name="ui-footer"]').getAttribute("content");
      // oxlint-disable-next-line vitest/no-conditional-in-test
      if (!footerName) {
        throw new Error("Rails must supply the translated footer name");
      }
      // Base's server-owned chrome deliberately has no footer navigation.
      await expect(page.getByRole("navigation", { name: footerName })).toHaveCount(0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
        320,
      );
      expect(
        (
          await new AxeBuilder({ page })
            .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
            .analyze()
        ).violations,
      ).toEqual([]);
    });
  }
}
