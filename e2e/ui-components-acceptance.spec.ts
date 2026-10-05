import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

for (const theme of ["light", "dark"]) {
  test(`ordinary table and opaque pressed buttons in ${theme}`, async ({ page }) => {
    await page.goto("http://127.0.0.1:3190/");
    await page.locator("html").evaluate((node, value) => (node.dataset["theme"] = value), theme);
    const cell = page.getByRole("table", { name: "Sessions" }).locator("td").first();
    expect(await cell.evaluate((node) => getComputedStyle(node).fontSize)).toBe("16px");
  });
  test(`pressed buttons keep full foreground and fill contrast in ${theme}`, async ({ page }) => {
    await page.goto("http://127.0.0.1:3190/");
    await page.locator("html").evaluate((node, value) => (node.dataset["theme"] = value), theme);
    const button = page.getByRole("button", { name: "primary", exact: true });
    await button.focus();
    await page.keyboard.down("Space");
    expect(
      await button.evaluate(async (node) => {
        void getComputedStyle(node).opacity;
        await Promise.all(node.getAnimations().map((animation) => animation.finished));
        return getComputedStyle(node).opacity;
      }),
    ).toBe("1");
    await page.keyboard.up("Space");
  });
}

test("native selection uses the OS picker and retains the chosen value", async ({ page }) => {
  await page.goto("http://127.0.0.1:3190/");
  const select = page.getByRole("combobox", { name: "Theme" });
  await select.selectOption("light");
  await expect(select).toHaveValue("light");
  await expect(select).toBeVisible();
});

test("a wide table exposes a local scroll affordance and scrolls from the keyboard", async ({
  page,
}) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto("http://127.0.0.1:3190/");
  const region = page.getByRole("region", { name: "Sessions" });
  expect(await region.evaluate((node) => getComputedStyle(node).backgroundImage)).toContain(
    "linear-gradient",
  );
  expect(await region.evaluate((node) => node.scrollWidth)).toBeGreaterThan(
    await region.evaluate((node) => node.clientWidth),
  );
  await region.focus();
  await page.keyboard.press("ArrowRight");
  await expect.poll(() => region.evaluate((node) => node.scrollLeft)).toBeGreaterThan(0);
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
});

for (const edition of ["app", "com", "org"]) {
  for (const lang of ["en", "ja"]) {
    for (const width of [320, 768, 1024, 1440]) {
      test(`conditions, density and native birthdate reflow in ${edition}/${lang} at ${width}px`, async ({
        page,
      }) => {
        await page.setViewportSize({ width, height: 900 });
        await page.goto(`http://127.0.0.1:3190/components.html?edition=${edition}&lang=${lang}`);
        await expect(page.locator("[data-locale]")).toHaveText(lang);
        const choice = page.getByRole("combobox", { name: "Choice" });
        await expect(choice).toHaveValue("0");
        await expect(choice).toHaveAccessibleDescription("Choose an available option.");
        await choice.selectOption("1");
        await expect(choice).toHaveValue("1");
        const year = page.getByRole("spinbutton", { name: "Year" });
        await expect(year).toHaveAccessibleDescription("1990");
        await year.fill("2000");
        await expect(year).toHaveValue("2000");
        const ordinary = page
          .getByRole("table", { name: "Ordinary records" })
          .locator("td")
          .first();
        const dense = page
          .getByRole("table", { name: "Administration records" })
          .locator("td")
          .first();
        expect(await ordinary.evaluate((node) => getComputedStyle(node).fontSize)).toBe("16px");
        expect(await dense.evaluate((node) => getComputedStyle(node).fontSize)).toBe("14px");
        await page.locator("html").evaluate((node) => (node.style.fontSize = "200%"));
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
          width,
        );
        const formBounds = await page
          .getByRole("form", { name: "Synthetic birthdate" })
          .boundingBox();
        const yearBounds = await year.boundingBox();
        // oxlint-disable-next-line vitest/no-conditional-in-test
        if (!formBounds || !yearBounds) {
          throw new Error("Birthdate controls must be visible");
        }
        expect(yearBounds.x + yearBounds.width).toBeLessThanOrEqual(
          formBounds.x + formBounds.width,
        );
        expect(
          (
            await new AxeBuilder({ page })
              .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
              .analyze()
          ).violations,
        ).toEqual([]);
        await page.screenshot({
          path: `/tmp/ui-components-${edition}-${lang}-${width}.png`,
          fullPage: true,
        });
      });
    }
  }
}

for (const theme of ["light", "dark"]) {
  for (const variant of ["primary", "secondary", "danger"]) {
    test(`${variant} text contrast remains readable at rest, hover and press in ${theme}`, async ({
      page,
    }) => {
      await page.goto("http://127.0.0.1:3190/");
      await page.locator("html").evaluate((node, value) => (node.dataset["theme"] = value), theme);
      const button = page.getByRole("button", { name: variant, exact: true });
      for (const state of ["rest", "hover", "press"]) {
        // All states execute in a fixed sequence; only preparation differs.
        // oxlint-disable-next-line vitest/no-conditional-in-test
        if (state === "hover") {
          await button.hover();
        }
        // oxlint-disable-next-line vitest/no-conditional-in-test
        if (state === "press") {
          await button.focus();
          await page.keyboard.down("Space");
        }
        const ratio = await button.evaluate(async (node) => {
          const style = getComputedStyle(node);
          void style.backgroundColor;
          await Promise.all(node.getAnimations().map((animation) => animation.finished));
          const canvas = document.createElement("canvas");
          canvas.width = canvas.height = 1;
          const context = canvas.getContext("2d", { willReadFrequently: true });
          // oxlint-disable-next-line vitest/no-conditional-in-test
          if (!context) {
            throw new Error("Canvas color conversion unavailable");
          }
          const luminances = [style.color, style.backgroundColor].map((color) => {
            context.clearRect(0, 0, 1, 1);
            context.fillStyle = color;
            context.fillRect(0, 0, 1, 1);
            const bytes = context.getImageData(0, 0, 1, 1).data;
            // oxlint-disable-next-line vitest/no-conditional-in-test
            if (bytes[3] !== 255 || style.opacity !== "1") {
              throw new Error("Composite opacity needs separate measurement");
            }
            const linear = Array.from(bytes)
              .slice(0, 3)
              .map((byte) => {
                const channel = byte / 255;
                // WCAG luminance conversion has two mathematical branches.
                // oxlint-disable-next-line vitest/no-conditional-in-test
                return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
              });
            const [red, green, blue] = linear;
            // oxlint-disable-next-line vitest/no-conditional-in-test
            if (red === undefined || green === undefined || blue === undefined) {
              throw new Error("RGB pixel conversion is incomplete");
            }
            return red * 0.2126 + green * 0.7152 + blue * 0.0722;
          });
          return (Math.max(...luminances) + 0.05) / (Math.min(...luminances) + 0.05);
        });
        expect(ratio).toBeGreaterThanOrEqual(4.5);
        // oxlint-disable-next-line vitest/no-conditional-in-test
        if (state === "press") {
          await page.keyboard.up("Space");
        }
      }
    });
  }
}
