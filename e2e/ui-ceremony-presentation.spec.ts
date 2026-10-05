import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Isolated UI composition; never described as an admitted application/authentication journey.
for (const screen of ["methods", "checkpoint", "otp", "secret"]) {
  for (const width of [320, 768, 1024, 1440]) {
    test(`${screen} ceremony composition reflows at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.route("**/synthetic/**", (route) => route.abort());
      await page.goto(`http://127.0.0.1:3190/ceremony.html?screen=${screen}`);
      await expect(page.getByRole("main").getByRole("heading", { level: 1 })).toBeVisible();
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
      // The native OTP autofocus remains part of its existing behavior.
      const controls = page.locator('main button, main a, main input:not([type="hidden"])');
      for (const control of await controls.all()) {
        await control.focus();
        await expect(control).toBeFocused();
      }
      await page.screenshot({
        path: `/tmp/umaxica-ui-normalization-continuation/ceremony-${screen}-${width}.png`,
        fullPage: true,
      });
    });
  }
}

test("Secret native validity preserves the exact 32-character boundary and accepted alphabet", async ({
  page,
}) => {
  await page.goto("http://127.0.0.1:3190/ceremony.html?screen=secret");
  const control = page.getByLabel("Secret", { exact: true });
  expect((await control.boundingBox())?.height).toBeGreaterThanOrEqual(44);
  for (const value of [
    "",
    "0",
    "1".repeat(31),
    "1".repeat(32),
    "1".repeat(33),
    "0".repeat(32),
    "1".repeat(31) + "\0",
  ]) {
    // Programmatically setting value does not set the native tooShort/tooLong flags; the original
    // exact-length pattern covers both neighbors, including the non-user-typeable 33rd character.
    await control.evaluate((node, candidate) => {
      // oxlint-disable-next-line vitest/no-conditional-in-test -- fail explicitly if the fixture control has the wrong DOM type.
      if (!(node instanceof HTMLInputElement)) {
        throw new Error("The Secret control is not an input.");
      }
      node.value = candidate;
    }, value);
    expect(
      // oxlint-disable-next-line vitest/no-conditional-in-test -- this guard validates the actual DOM type as well as native validity.
      await control.evaluate((node) => node instanceof HTMLInputElement && node.checkValidity()),
    ).toBe(value === "1".repeat(32));
  }
  await expect(control).toHaveAttribute("autocomplete", "current-password");
  await expect(control).toHaveAttribute("name", "secret");
  await expect(page.locator("form")).toHaveAttribute("method", "post");
});
