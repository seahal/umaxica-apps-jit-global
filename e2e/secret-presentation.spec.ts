import { expect, test } from "playwright/test";

// Browser coverage of the shipped presentation entrypoint, not Rails authorization
// or a full authenticated back/forward journey. The values below are synthetic.
const fixtureOrigin = "http://127.0.0.1:3190";
const values = ["a".repeat(32), "b".repeat(32)];

test.beforeEach(async ({ page }) => {
  await page.goto(fixtureOrigin);
  await page.setContent(`<!doctype html><html><body>
    <main>${values.map((value) => `<p data-secret-value><code>${value}</code></p>`).join("")}
    <form><label><input type="checkbox" name="stored" required>Saved</label>
    <button type="submit">Confirm</button></form></main>
    </body></html>`);
  await page.addScriptTag({
    type: "module",
    url: `${fixtureOrigin}/@fs${process.cwd()}/src/entrypoints/secret_presentation.ts`,
  });
  await expect(page.locator("[data-secret-value]")).toHaveText(values);
});

test("pagehide removes every value before a document can enter the back-forward cache", async ({
  page,
}) => {
  await page.evaluate(() =>
    window.dispatchEvent(new PageTransitionEvent("pagehide", { persisted: true })),
  );
  await expect(page.locator("[data-secret-value]")).toHaveText(["", ""]);
  expect(await page.content()).not.toContain(values[0]);
  expect(await page.content()).not.toContain(values[1]);
});

test("persisted pageshow clears restored values while initial pageshow preserves delivery", async ({
  page,
}) => {
  await page.evaluate(() =>
    window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: false })),
  );
  await expect(page.locator("[data-secret-value]")).toHaveText(values);
  await page.evaluate(() =>
    window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: true })),
  );
  await expect(page.locator("[data-secret-value]")).toHaveText(["", ""]);
});

test("native validation preserves unsaved values and accepted submission clears them", async ({
  page,
}) => {
  await page.evaluate(() =>
    document.querySelector("form")?.addEventListener("submit", (event) => event.preventDefault()),
  );
  await page.getByRole("button", { name: "Confirm" }).click();
  await expect(page.locator("[data-secret-value]")).toHaveText(values);
  await page.getByRole("checkbox", { name: "Saved" }).check();
  await page.getByRole("button", { name: "Confirm" }).click();
  await expect(page.locator("[data-secret-value]")).toHaveText(["", ""]);
  expect(await page.evaluate(() => JSON.stringify(history.state))).not.toContain(values[0]);
  const persistedBrowserState = await page.evaluate(() =>
    JSON.stringify({
      local: Object.entries(localStorage),
      session: Object.entries(sessionStorage),
      history: history.state as unknown,
      url: location.href,
    }),
  );
  for (const value of values) {
    expect(persistedBrowserState).not.toContain(value);
  }
});
