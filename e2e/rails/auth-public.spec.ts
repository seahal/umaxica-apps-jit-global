import { test, expect } from "./fixtures";

test("Auth public landing mounts its Inertia React page", async ({ page }) => {
  const response = await page.goto("/?ri=jp");
  expect(response?.status()).toBe(200);
  // The ERB shell contains serialized Inertia props but no h1 or authentication navigation.
  // These role assertions require React to create visible elements in the live document.
  await expect(page.getByRole("heading", { name: "Sign App", exact: true })).toBeVisible();
  await expect(page.getByRole("navigation", { name: "Authentication", exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "Sign in", exact: true })).toBeVisible();
  await expect(page.locator('meta[name="csrf-token"]')).toHaveAttribute("content", /\S+/u);
  expect(await page.evaluate(() => "turnstile" in window)).toBe(false);
  await expect(page).toHaveURL("http://auth.app.localhost:3198/?ri=jp");
});
