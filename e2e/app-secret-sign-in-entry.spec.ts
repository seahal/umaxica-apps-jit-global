import { expect, test } from "playwright/test";

process.env["PLAYWRIGHT_NO_COPY_PROMPT"] = "1";

const runner = process.env["E2E_ISOLATED_RAILS_RUNNER"];
const backend = process.env["E2E_BASE_SERVICE_URL"];
const baseHost = process.env["PUBLIC_BASE_SERVICE_URL"];
const authHost = process.env["PUBLIC_AUTH_SERVICE_URL"];
const jumpOrigin = process.env["E2E_JUMP_SERVICE_URL"];
if (!runner || !backend || !baseHost || !authHost || !jumpOrigin) {
  throw new Error(
    "Explicit isolated runner, backend, public app hosts and Jump origin are required",
  );
}

// A task-owned HTTPS proxy preserves real redirect responses and browser cookies.
// Chromium resolves only these explicit test origins; other network hosts fail closed.
test.use({
  trace: "off",
  screenshot: "off",
  video: "off",
  serviceWorkers: "block",
  ignoreHTTPSErrors: true,
  launchOptions: {
    args: [
      "--no-proxy-server",
      `--host-resolver-rules=MAP ${baseHost} 127.0.0.1:3443, MAP ${authHost} 127.0.0.1:3443, MAP ${new URL(jumpOrigin).hostname} 127.0.0.1:3443, MAP challenges.cloudflare.com 127.0.0.1:3443, MAP * ~NOTFOUND`,
    ],
  },
});

for (const region of ["us", "jp"]) {
  test(`server-issued browser admission reaches the sixth Secret entry for ri=${region}`, async ({
    page,
  }) => {
    await page.goto(`https://${baseHost}/sign?ri=${region}`);
    await page.locator("form input[type=submit]").click();
    await expect
      .poll(() => {
        const current = new URL(page.url());
        return `${current.hostname}${current.pathname}`;
      })
      .toBe(`${authHost}/sign/in`);
    // The nonce-bearing admission document submits its own CSRF-protected form.
    await expect(page.locator('a[href*="/sign/in/email"]')).toBeVisible();
    await expect(page.locator('a[href*="/sign/in/passkey"]')).toBeVisible();
    await expect(page.locator('a[href*="/sign/in/device"]')).toBeVisible();
    await expect(page.locator('form[action*="/google"] button')).toBeVisible();
    await expect(page.locator('form[action*="/apple"] button')).toBeVisible();
    const secret = page.locator('a[href*="/sign/in/secret/new"]');
    await expect(secret).toBeVisible();
    const href = await secret.getAttribute("href");
    expect(href).not.toBeNull();
    const destination = new URL(href!);
    expect(destination.pathname).toBe("/sign/in/secret/new");
    expect(destination.searchParams.get("ri")).toBe(region);
    await secret.click();
    await expect(page.locator("input[name=secret]")).toBeVisible();
    expect(new URL(page.url()).pathname).toBe("/sign/in/secret/new");
  });
}

test("a browser-saved manual Secret establishes one normal root login and rejects reuse", async ({
  page,
  context,
}) => {
  test.setTimeout(90_000);
  // This fixture supplies an existing authorized management session. Root login below
  // must be issued by the real Base completion boundary, never by this fixture.
  const fixture: unknown = JSON.parse(
    execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
actor = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: '2000-01-01')
actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: 'public-key')
token = ClientToken.create!(user: actor, root_login_established_at: ClientToken.database_now, established_authentication_method: 'passkey')
BaseSelectorBootstrapAuthority.call(surface: :app, principal: actor)
BaseSelectorAuthority.prepare(surface: :app, principal: actor, session: token)
token.update!(last_step_up_at: ClientToken.database_now, last_step_up_scope: 'settings_secret_credential', last_step_up_method: 'passkey', last_step_up_session_public_id: token.public_id, last_step_up_purpose: 'step_up', last_step_up_audience: 'step_up:app')
access = AuthenticationToken.encode(actor, host: ENV.fetch('PUBLIC_BASE_SERVICE_URL'), session_public_id: token.public_id, resource_type: 'client', jwt_issuer_id: 'surface:BASE_APP')
STDOUT.write({cookie: AuthenticationBase::ACCESS_COOKIE_KEY, access: access, tokenId: token.id}.to_json)
`,
      ],
      { encoding: "utf8" },
    ),
  );
  assert.ok(typeof fixture === "object");
  assert.ok(fixture !== null);
  assert.ok("cookie" in fixture);
  assert.ok("access" in fixture);
  assert.ok("tokenId" in fixture);
  assert.ok(typeof fixture.cookie === "string");
  assert.ok(typeof fixture.access === "string");
  assert.ok(typeof fixture.tokenId === "number");
  const cookieName = fixture.cookie;
  try {
    await context.addCookies([
      {
        name: fixture.cookie,
        value: fixture.access,
        url: `https://${baseHost}`,
        httpOnly: true,
        secure: true,
      },
    ]);
    await page.goto(`https://${baseHost}/secrets/new?ri=jp`);
    await page.locator("form button[type=submit]").first().click();
    await expect(page.locator("form button[type=submit]").first()).toBeVisible();
    await page.locator("form button[type=submit]").first().click();
    await expect(page.locator("[data-secret-value] code")).toHaveCount(1);
    const raw = await page.locator("[data-secret-value] code").innerText();
    expect(raw.length).toBe(32);
    await page.locator("input[type=checkbox]").check();
    await page.locator("input[type=submit]").first().click();
    await expect(page.locator('a[href*="/secrets/new"]')).toBeVisible();
    execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
token = ClientToken.find(${fixture.tokenId})
token.revoke!
deadline = token.root_login_established_at + AuthenticationBase.login_cooldown
Timeout.timeout(40) { sleep 0.05 while ClientToken.database_now <= deadline }
`,
      ],
      { stdio: "pipe" },
    );
    await context.clearCookies();
    await page.goto(`https://${baseHost}/sign?ri=jp`);
    await page.locator("form input[type=submit]").click();
    await page.locator('a[href*="/sign/in/secret/new"]').click();
    await page.locator("input[name=secret]").fill(raw);
    await expect(page.locator('input[name="cf-turnstile-response"]:not([readonly])')).toHaveValue(
      "synthetic",
    );
    await page.locator("form button[type=submit]").click();
    // Auth's handoff and result documents submit their own nonce-bearing forms.
    await expect
      .poll(async () =>
        (await context.cookies()).some(
          (cookie) => `${cookie.name}:${cookie.domain}` === `${cookieName}:${baseHost}`,
        ),
      )
      .toBe(true);
    await page.waitForURL((url) => `${url.hostname}${url.pathname}` === `${baseHost}/dashboard`, {
      waitUntil: "domcontentloaded",
    });
    const proof = execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
actor = ClientToken.find(${fixture.tokenId}).user
roots = ClientToken.where(user_id: actor.id, established_authentication_method: 'secret').where.not(root_login_established_at: nil)
receipt = ClientSecretSignInReceipt.find_by!(client_ref: actor.public_id)
credential = ClientSecretCredential.find_by!(public_id: receipt.credential_ref)
STDOUT.write({roots: roots.count, bound: roots.exists?(public_id: receipt.root_token_ref), consumed: credential.consumed_at.present?, claimed: credential.claim_operation_id == receipt.operation_id}.to_json)
`,
      ],
      { encoding: "utf8" },
    );
    expect(proof).toBe('{"roots":1,"bound":true,"consumed":true,"claimed":true}');
    const audit = execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `
raw = STDIN.read
actor = ClientToken.find(${fixture.tokenId}).user
receipt = ClientSecretSignInReceipt.find_by!(client_ref: actor.public_id)
credential = ClientSecretCredential.find_by!(public_id: receipt.credential_ref)
ClientSecretAuditDeliveryJob.perform_now(batch_size: 500, retention_seconds: 604800)
events = ClientSecretAuditOutbox.where(client_ref: actor.public_id)
ids = events.pluck(:event_id)
delivered = ids.any? && events.where(delivered_at: nil).count.zero? && Chronicle.where(event_uuid: ids).count == ids.uniq.size
source = ClientSecretAuditOutbox.where(client_ref: actor.public_id).map(&:attributes).to_json
chronicle = Chronicle.where("metadata @> ?::jsonb", { client_ref: actor.public_id }.to_json).map(&:attributes).to_json
materials = [raw, credential.lookup_digest, credential.password_digest]
log = File.binread(Rails.root.join('log/test.log'))
STDOUT.write({delivered: delivered, log_clean: !log.include?(raw), source_clean: materials.none? { |value| source.include?(value) }, chronicle_clean: materials.none? { |value| chronicle.include?(value) }}.to_json)
`,
      ],
      { input: raw, encoding: "utf8" },
    );
    expect(audit).toBe(
      '{"delivered":true,"log_clean":true,"source_clean":true,"chronicle_clean":true}',
    );
    const residual = await page.evaluate(
      (value) =>
        JSON.stringify([history.state, localStorage, sessionStorage, location.href]).includes(
          value,
        ),
      raw,
    );
    expect(residual).toBe(false);
    await context.clearCookies();
    await page.goto(`https://${baseHost}/sign?ri=jp`);
    await page.locator("form input[type=submit]").click();
    await page.locator('a[href*="/sign/in/secret/new"]').click();
    await page.locator("input[name=secret]").fill(raw);
    await expect(page.locator('input[name="cf-turnstile-response"]:not([readonly])')).toHaveValue(
      "synthetic",
    );
    const rejection = page.waitForResponse(
      (response) => new URL(response.url()).pathname === "/sign/in/secret",
    );
    await page.locator("form button[type=submit]").click();
    expect((await rejection).status()).toBe(422);
    await expect(page.locator("#secret-sign-in-error")).toBeVisible();
    const count = execFileSync(
      "bundle",
      [
        "exec",
        "ruby",
        runner,
        "runner",
        `STDOUT.write(ClientToken.where(user_id: ClientToken.find(${fixture.tokenId}).user_id, established_authentication_method: 'secret').where.not(root_login_established_at: nil).count.to_s)`,
      ],
      { encoding: "utf8" },
    );
    expect(count).toBe("1");
  } finally {
    execFileSync(
      "bundle",
      ["exec", "ruby", runner, "runner", `ClientToken.find(${fixture.tokenId}).revoke!`],
      { stdio: "pipe" },
    );
  }
});
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
