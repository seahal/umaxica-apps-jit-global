import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Real presentation components, isolated from application admission and authentication journeys.
for (const theme of ["light", "dark"]) {
  test(`keyboard focus, link feedback and dialog boundary in ${theme}`, async ({ page }) => {
    await page.goto("http://127.0.0.1:3190/");
    await page.locator("html").evaluate((node, value) => (node.dataset["theme"] = value), theme);
    const button = page.getByRole("button", { name: "primary", exact: true });
    await button.focus();
    const focus = await button.evaluate((node) => {
      const style = getComputedStyle(node);
      return { outline: style.outlineColor, width: style.outlineWidth, shadow: style.boxShadow };
    });
    expect(focus.outline).toBe("rgb(0, 0, 0)");
    expect(focus.width).toBe("4px");
    expect(focus.shadow).toContain("rgb(255, 212, 61)");
    const link = page.getByRole("link", { name: "inline link", exact: true });
    const resting = await link.evaluate((node) => getComputedStyle(node).textDecorationThickness);
    await link.hover();
    expect(await link.evaluate((node) => getComputedStyle(node).textDecorationThickness)).not.toBe(
      resting,
    );
    await page.getByRole("button", { name: "Open the dialog" }).click();
    const modal = page.getByRole("dialog").locator("..");
    const boundary = await modal.evaluate((node) => {
      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = 1;
      const context = canvas.getContext("2d");
      // DOM guards fail this test; they never select or skip an assertion.
      // oxlint-disable-next-line vitest/no-conditional-in-test
      if (!context || !node.parentElement) {
        throw new Error("Missing modal boundary");
      }
      const style = getComputedStyle(node);
      const backgrounds = [
        [style.borderTopColor],
        [style.backgroundColor],
        [
          getComputedStyle(document.body).backgroundColor,
          getComputedStyle(node.parentElement).backgroundColor,
        ],
      ];
      const luminances = backgrounds.map((colors) => {
        context.clearRect(0, 0, 1, 1);
        for (const color of colors) {
          context.fillStyle = color;
          context.fillRect(0, 0, 1, 1);
        }
        const channels = Array.from(context.getImageData(0, 0, 1, 1).data)
          .slice(0, 3)
          .map((value) => {
            const channel = value / 255;
            // The WCAG transfer function is piecewise; every measured channel is asserted.
            // oxlint-disable-next-line vitest/no-conditional-in-test
            return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
          });
        return channels[0]! * 0.2126 + channels[1]! * 0.7152 + channels[2]! * 0.0722;
      });
      return luminances
        .slice(1)
        .map(
          (background) =>
            (Math.max(luminances[0]!, background) + 0.05) /
            (Math.min(luminances[0]!, background) + 0.05),
        );
    });
    expect(boundary[0]).toBeGreaterThanOrEqual(3);
    expect(boundary[1]).toBeGreaterThanOrEqual(3);
    await page.screenshot({ path: `/tmp/umaxica-foundations/dialog-${theme}.png` });
    await page.keyboard.press("Escape");
    await expect(page.getByRole("button", { name: "Open the dialog" })).toBeFocused();
  });
}

test("notification explanations are readable and described by their checkbox", async ({ page }) => {
  await page.route("**/*", (route) =>
    // Isolate outbound requests; this branch does not select test cases or assertions.
    // oxlint-disable-next-line vitest/no-conditional-in-test
    new URL(route.request().url()).hostname === "127.0.0.1" ? route.continue() : route.abort(),
  );
  await page.goto("http://127.0.0.1:3190/foundations.html?screen=preferences");
  const description = page.getByText("Choose whether to receive promotional notices.", {
    exact: true,
  });
  expect(await description.evaluate((node) => getComputedStyle(node).fontSize)).toBe("16px");
  const checkbox = page.getByRole("checkbox", { name: "Promotional notices", exact: true });
  await expect(checkbox).toHaveAccessibleDescription(
    "Choose whether to receive promotional notices.",
  );
  const label = page.locator("label").filter({ has: checkbox });
  const form = page.locator('form[action="/synthetic/preferences"]');
  expect(
    await form.evaluate((node) => {
      // The guard fails missing form rendering, rather than bypassing an assertion.
      // oxlint-disable-next-line vitest/no-conditional-in-test
      if (!(node instanceof HTMLFormElement)) {
        throw new Error("Expected the preference form");
      }
      return new FormData(node).getAll("email[promotional]");
    }),
  ).toEqual(["0"]);
  await label.click();
  await expect(checkbox).toBeChecked();
  expect(
    await form.evaluate((node) => {
      // The guard fails missing form rendering, rather than bypassing an assertion.
      // oxlint-disable-next-line vitest/no-conditional-in-test
      if (!(node instanceof HTMLFormElement)) {
        throw new Error("Expected the preference form");
      }
      return new FormData(node).getAll("email[promotional]");
    }),
  ).toEqual(["0", "1"]);
  await checkbox.focus();
  expect(await label.evaluate((node) => getComputedStyle(node).outlineWidth)).toBe("4px");
});

for (const lang of ["en", "ja"]) {
  for (const width of [320, 768, 1024, 1440]) {
    test(`reading paragraphs keep their relationship at ${width}px in ${lang}`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.route("**/synthetic/**", (route) => route.abort());
      await page.goto(`http://127.0.0.1:3190/foundations.html?lang=${lang}`);
      const paragraphs = page.getByRole("main").locator("p");
      const geometry = await paragraphs.evaluateAll((nodes) => {
        const [first, second] = nodes;
        // Missing rendering fails the test, rather than bypassing a geometry assertion.
        // oxlint-disable-next-line vitest/no-conditional-in-test
        if (!first || !second) {
          throw new Error("Expected two reading paragraphs");
        }
        return {
          gap: second.getBoundingClientRect().top - first.getBoundingClientRect().bottom,
          line: parseFloat(getComputedStyle(first).lineHeight),
          width: first.getBoundingClientRect().width,
          font: parseFloat(getComputedStyle(first).fontSize),
        };
      });
      expect(geometry.gap).toBeGreaterThanOrEqual(geometry.line * 1.5 - 1);
      expect(geometry.width).toBeLessThanOrEqual(geometry.font * 40);
      await page.locator("html").evaluate((node) => (node.style.fontSize = "200%"));
      await page.addStyleTag({
        content:
          "p { letter-spacing: .12em !important; word-spacing: .16em !important; line-height: 1.5 !important; }",
      });
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
        path: `/tmp/umaxica-foundations/reading-${lang}-${width}.png`,
        fullPage: true,
      });
    });
  }
}

test("navigation icons stay decorative and focus survives forced colors", async ({ page }) => {
  await page.goto("http://127.0.0.1:3190/");
  const row = page.getByRole("link", { name: "Passkey", exact: true });
  await expect(row.locator('[aria-hidden="true"]')).toHaveText("→");
  expect(await row.evaluate((node) => getComputedStyle(node).borderRadius)).toBe("6px");
  await page.emulateMedia({ forcedColors: "active" });
  await row.focus();
  expect(await row.evaluate((node) => getComputedStyle(node).outlineStyle)).toBe("solid");
  expect(await row.evaluate((node) => getComputedStyle(node).outlineWidth)).toBe("4px");
  expect(await row.evaluate((node) => getComputedStyle(node).boxShadow)).toBe("none");
});
