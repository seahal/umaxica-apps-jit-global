import { execFileSync } from "node:child_process";

import { expect, test } from "playwright/test";

// Established-session setup verifies delivery authorization, not root login issuance.
// Credentials stay in memory; browser artifacts must never retain delivered plaintext.
process.env["PLAYWRIGHT_NO_COPY_PROMPT"] = "1";

test.use({ trace: "off", screenshot: "off", video: "off" });

const origin = process.env["E2E_BASE_SERVICE_URL"];
const runner = process.env["E2E_ISOLATED_RAILS_RUNNER"];
if (!origin || !runner) {
  throw new Error("E2E_BASE_SERVICE_URL and E2E_ISOLATED_RAILS_RUNNER are required");
}
let fixture: { cookie: string; access: string; tokenId: number } | null = null;

test.beforeEach(() => {
  const payload: unknown = JSON.parse(
    execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: '2000-01-01')
token = ClientToken.create!(user: actor, root_login_established_at: ClientToken.database_now, established_authentication_method: 'passkey')
BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
token.update!(last_step_up_at: ClientToken.database_now, last_step_up_scope: 'settings_secret_credential', last_step_up_method: 'passkey', last_step_up_session_public_id: token.public_id, last_step_up_purpose: 'step_up', last_step_up_audience: 'step_up:app')
access = AuthenticationToken.encode(actor, host: 'base.app.localhost', session_public_id: token.public_id, resource_type: 'client', jwt_issuer_id: 'surface:BASE_APP')
STDOUT.write({cookie: AuthenticationBase::ACCESS_COOKIE_KEY, access: access, tokenId: token.id}.to_json)
`,
      ],
      { encoding: "utf8" },
    ),
  );
  if (
    typeof payload !== "object" ||
    payload === null ||
    !("cookie" in payload) ||
    !("access" in payload) ||
    !("tokenId" in payload) ||
    typeof payload.cookie !== "string" ||
    typeof payload.access !== "string" ||
    typeof payload.tokenId !== "number"
  ) {
    throw new Error("The isolated session fixture has an invalid shape");
  }
  fixture = { cookie: payload.cookie, access: payload.access, tokenId: payload.tokenId };
});

test.afterEach(() => {
  if (fixture) {
    execFileSync(
      "bundle",
      ["exec", "ruby", runner, "runner", `ClientToken.find(${fixture.tokenId}).revoke!`],
      { stdio: "pipe" },
    );
  }
});

test("Rails delivery leaves no plaintext in history or storage and does not restore it on back", async ({
  page,
  context,
}) => {
  await context.addCookies([
    { name: fixture!.cookie, value: fixture!.access, url: origin, httpOnly: true },
  ]);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto(`${origin}/secrets/new?ri=jp`);
  await expect(page.locator("form button[type=submit]").first()).toBeVisible();
  await page.locator("form button[type=submit]").first().click();
  await expect(page).toHaveURL(/\/secret_issuances\//u);
  const responsePromise = page.waitForResponse("**/secret_issuances/*/presentation*");
  await page.locator("form button[type=submit]").first().click();
  const delivered = await responsePromise;
  expect(delivered.request().method()).toBe("POST");
  expect(delivered.headers()["cache-control"]).toContain("no-store");
  await expect(page.locator("[data-secret-value] code")).toHaveCount(1);
  const raw = await page.locator("[data-secret-value] code").innerText();
  expect(raw.length).toBe(32);
  const residual = await page.evaluate(
    (value) => ({
      history: JSON.stringify(history.state).includes(value),
      local: JSON.stringify(localStorage).includes(value),
      session: JSON.stringify(sessionStorage).includes(value),
      url: location.href.includes(value),
    }),
    raw,
  );
  expect(Object.values(residual).some(Boolean)).toBe(false);
  const cached = await page.evaluate(async (value) => {
    const entries = await Promise.all(
      (await caches.keys()).map(async (key) => {
        const cache = await caches.open(key);
        return Promise.all(
          (await cache.keys()).map(async (request) => {
            const response = await cache.match(request);
            return [request.url, await response?.text()];
          }),
        );
      }),
    );
    return entries.flat(2).some((entry) => entry?.includes(value));
  }, raw);
  expect(cached).toBe(false);
  expect((await context.cookies()).some((cookie) => cookie.value.includes(raw))).toBe(false);
  await page.locator("input[type=checkbox]").check();
  await page.locator("input[type=submit]").first().click();
  await expect(page).toHaveURL(/\/secrets(?:\?|$)/u);
  // Chromium may refuse the no-store POST document instead of restoring it.
  await page.goBack().catch((error: unknown) => {
    expect(String(error).includes("net::ERR_CACHE_MISS")).toBe(true);
  });
  await expect
    .poll(() =>
      page.content().then(
        (content) => !content.includes(raw),
        (error: unknown) => {
          expect(String(error).includes("page is navigating")).toBe(true);
          return false;
        },
      ),
    )
    .toBe(true);
  expect(errors.length).toBe(0);
});

test("reload and another tab cannot reveal or confirm an unconfirmed Rails presentation", async ({
  page,
  context,
}) => {
  await context.addCookies([
    { name: fixture!.cookie, value: fixture!.access, url: origin, httpOnly: true },
  ]);
  await page.goto(`${origin}/secrets/new?ri=jp`);
  await page.locator("form button[type=submit]").first().click();
  await expect(page).toHaveURL(/\/secret_issuances\//u);
  const resumeUrl = page.url();
  await page.locator("form button[type=submit]").first().click();
  await expect(page.locator("[data-secret-value] code")).toHaveCount(1);
  const raw = await page.locator("[data-secret-value] code").innerText();
  expect(raw.length).toBe(32);
  const sibling = await context.newPage();
  await sibling.goto(resumeUrl);
  await expect(sibling.locator("[data-secret-value]")).toHaveCount(0);
  expect((await sibling.content()).includes(raw)).toBe(false);
  await sibling.close();
  await page.reload();
  await expect(page).toHaveURL(/\/secret_issuances\/[^/]+(?:\?|$)/u);
  await expect(page.locator("[data-secret-value]")).toHaveCount(0);
  expect((await page.content()).includes(raw)).toBe(false);
  expect(await page.evaluate((value) => JSON.stringify(history.state).includes(value), raw)).toBe(
    false,
  );
  const state: unknown = JSON.parse(
    execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
token = ClientToken.find(${fixture!.tokenId})
issuance = ClientSecretIssuance.where(client_id: token.user_id).order(id: :desc).first!
STDOUT.write({candidate_count: ClientSecretCredential.where(issuance_id: issuance.id).count, confirmed: issuance.confirmed_at.present?, presented: issuance.presented_at.present?, payload: issuance.encrypted_payload.present?}.to_json)
`,
      ],
      { encoding: "utf8" },
    ),
  );
  expect(state).toEqual({ candidate_count: 1, confirmed: false, presented: true, payload: false });
});

test("active Rails Service Worker never caches delivered values and offline fallback has no plaintext", async ({
  page,
  context,
}) => {
  await context.addCookies([
    { name: fixture!.cookie, value: fixture!.access, url: origin, httpOnly: true },
  ]);
  await page.goto(`${origin}/secrets/new?ri=jp`);
  await page.evaluate(async () => {
    await navigator.serviceWorker.register("/service-worker");
    await navigator.serviceWorker.ready;
  });
  await page.reload();
  await expect
    .poll(() => page.evaluate(() => navigator.serviceWorker.controller !== null))
    .toBe(true);
  await page.locator("form button[type=submit]").first().click();
  await expect(page).toHaveURL(/\/secret_issuances\//u);
  const locator = page.url();
  await page.locator("form button[type=submit]").first().click();
  await expect(page.locator("[data-secret-value] code")).toHaveCount(1);
  const raw = await page.locator("[data-secret-value] code").innerText();
  expect(raw.length).toBe(32);
  const cached = await page.evaluate(async (value) => {
    const entries = await Promise.all(
      (await caches.keys()).map(async (key) => {
        const cache = await caches.open(key);
        return Promise.all(
          (await cache.keys()).map(async (request) => {
            const response = await cache.match(request);
            return [request.url, await response?.text()];
          }),
        );
      }),
    );
    return entries.flat(2).some((entry) => entry?.includes(value));
  }, raw);
  expect(cached).toBe(false);
  await page.locator("input[type=checkbox]").check();
  await page.locator("input[type=submit]").first().click();
  await expect(page).toHaveURL(/\/secrets(?:\?|$)/u);
  await context.setOffline(true);
  const offline = await page.goto(locator);
  expect(offline).not.toBeNull();
  expect(offline!.fromServiceWorker()).toBe(true);
  expect(offline!.status()).toBe(200);
  expect((await page.content()).includes(raw)).toBe(false);
  await expect(page.locator("[data-secret-value]")).toHaveCount(0);
  await context.setOffline(false);
});

test("losing the committed delivery response leaves one unconfirmed batch without redisplay", async ({
  page,
  context,
}) => {
  await context.addCookies([
    { name: fixture!.cookie, value: fixture!.access, url: origin, httpOnly: true },
  ]);
  await page.goto(`${origin}/secrets/new?ri=jp`);
  await page.locator("form button[type=submit]").first().click();
  await expect(page).toHaveURL(/\/secret_issuances\//u);
  const locator = page.url();
  await page.route("**/secret_issuances/*/presentation*", async (route) => {
    // Execute the actual HTTP request, then lose its committed response at the network boundary.
    const transport = new URL(route.request().url());
    const intendedHost = transport.host;
    transport.hostname = "127.0.0.1";
    const delivered = await route
      .fetch({
        url: transport.toString(),
        headers: { ...route.request().headers(), host: intendedHost },
      })
      .catch(() => {
        // Playwright transport diagnostics include request cookies; expose only this failure boundary.
        throw new Error("Local delivery transport failed before response-loss injection");
      });
    expect(delivered.status()).toBe(200);
    await delivered.dispose();
    await route.abort("failed");
  });
  await page
    .locator("form button[type=submit]")
    .first()
    .click()
    .catch((error: unknown) => {
      expect(String(error).includes("net::ERR_FAILED")).toBe(true);
    });
  // Resume in the same browser context without racing Chromium's failed-navigation document.
  const resumed = await context.newPage();
  await resumed.goto(locator);
  await expect(resumed.locator("[data-secret-value]")).toHaveCount(0);
  const state: unknown = JSON.parse(
    execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
token = ClientToken.find(${fixture!.tokenId})
issuance = ClientSecretIssuance.where(client_id: token.user_id).order(id: :desc).first!
STDOUT.write({issuance_count: ClientSecretIssuance.where(client_id: token.user_id).count, candidate_count: ClientSecretCredential.where(issuance_id: issuance.id).count, confirmed: issuance.confirmed_at.present?, usable: ClientSecretCredential.where(issuance_id: issuance.id).any? { |credential| credential.available_at?(at: Client.database_now) }, presented: issuance.presented_at.present?, payload: issuance.encrypted_payload.present?}.to_json)
`,
      ],
      { encoding: "utf8" },
    ),
  );
  expect(state).toEqual({
    issuance_count: 1,
    candidate_count: 1,
    confirmed: false,
    usable: false,
    presented: true,
    payload: false,
  });
  await resumed
    .locator("form")
    .filter({
      has: resumed.locator('input[name="_method"][value="delete"]'),
    })
    .getByRole("button")
    .click();
  await expect(resumed).toHaveURL(/\/secrets(?:\?|$)/u);
  await resumed.goto(`${origin}/secrets/new?ri=jp`);
  await resumed.locator("form button[type=submit]").first().click();
  await expect(resumed).toHaveURL(/\/secret_issuances\//u);
  expect(resumed.url() === locator).toBe(false);
  await resumed.locator("form button[type=submit]").first().click();
  await expect(resumed.locator("[data-secret-value] code")).toHaveCount(1);
  expect((await resumed.locator("[data-secret-value] code").innerText()).length).toBe(32);
  await resumed.locator("input[type=checkbox]").check();
  await resumed.locator("input[type=submit]").first().click();
  await expect(resumed).toHaveURL(/\/secrets(?:\?|$)/u);
  const completed: unknown = JSON.parse(
    execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
token = ClientToken.find(${fixture!.tokenId})
issuances = ClientSecretIssuance.where(client_id: token.user_id).order(:id).to_a
first, second = issuances
STDOUT.write({issuance_count: issuances.length, canceled_original: first.canceled_at.present?, original_usable: ClientSecretCredential.where(issuance_id: first.id).any? { |credential| credential.available_at?(at: Client.database_now) }, replacement_confirmed: second.confirmed_at.present?, active_count: ClientSecretCapacityQuery.call(client: token.user, at: Client.database_now).active_count, root_count: ClientToken.where(user_id: token.user_id).count}.to_json)
`,
      ],
      { encoding: "utf8" },
    ),
  );
  expect(completed).toEqual({
    issuance_count: 2,
    canceled_original: true,
    original_usable: false,
    replacement_confirmed: true,
    active_count: 1,
    root_count: 1,
  });
});
