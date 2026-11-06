import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";

import { expect, test } from "./auth-flow-fixtures";
import { railsOrigin } from "./settings";

test("browser Back after APP Email OTP reaches the old page and receives an unchanged 409", async ({
  page,
  context,
}) => {
  test.setTimeout(90_000);
  const rubyFixture = `
require Rails.root.join("test/support/oidc_test_entry").to_s
issuance = OidcTestEntry.issue!(
  surface: "app", intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
)
binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
auth_session, raw_sid = ClientAuthCeremonySession.issue!
binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
  reference: issuance.reference, surface: "app", expected_intent: "sign_up", binding:, raw_auth_sid: raw_sid,
)
admitted_session, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
  admission_purpose: payload.fetch("purpose"), previous_raw_sid: raw_sid,
  authorization_transaction_ref: issuance.transaction.transaction_id, expires_at: binding.expires_at,
)
binding.redeem!(auth_session:, admitted_auth_session: admitted_session)
cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
STDOUT.write([cookie_name, admitted_sid].join(9.chr) + 10.chr)
`;
  const fixtureOutput = execFileSync("bundle", ["exec", "bin/rails", "runner", "-"], {
    encoding: "utf8",
    input: rubyFixture,
    env: {
      ...process.env,
      RAILS_ENV: "test",
      RACK_ENV: "test",
      UMAXICA_RUNTIME_ROLE: "shared",
      VALKEY_NAMESPACE_WORKER_ID: "browser",
    },
  });
  const cookieLine = fixtureOutput.trimEnd();
  const separator = cookieLine.indexOf("\t");
  expect(separator).toBeGreaterThan(0);
  const cookieName = cookieLine.slice(0, separator);
  await context.addCookies([
    {
      name: cookieName,
      value: cookieLine.slice(separator + 1),
      url: railsOrigin,
      httpOnly: true,
      secure: cookieName.startsWith("__Host-"),
      sameSite: "Lax",
    },
  ]);

  await page.goto(`${railsOrigin}/sign/up?ri=jp`);
  await page.locator('a[href*="/sign/up/email/new"]').click();
  await page
    .locator('input[name="client_email[raw_address]"]')
    .fill(`history-${randomUUID()}@example.test`);
  const consent = page.locator('input[name="client_email[confirm_policy]"][value="1"]');
  await page.getByText("利用規約に同意する", { exact: true }).click();
  await expect(consent).toBeChecked();
  await expect(page.locator('input[name="cf-turnstile-response"]')).toHaveValue("e2e-turnstile");
  const emailEntryUrl = page.url();
  const otpStep = page.waitForURL((url) => url.pathname.includes("/sign/up/check/email/otp"), {
    waitUntil: "domcontentloaded",
  });
  await page.locator("form button[type=submit]").click();
  await otpStep;
  await expect(page.locator('input[name="client_email[pass_code]"]')).toBeVisible();

  const backResponse = await page.goBack({ waitUntil: "domcontentloaded" });
  expect(backResponse).not.toBeNull();
  expect(backResponse!.status()).toBe(409);
  expect(page.url()).toBe(emailEntryUrl);
  expect(await backResponse!.text()).toBe(
    "この画面は古くなっています。最初からやり直してください。",
  );
  const responseHeaders = await backResponse!.headersArray();
  const headerNames = responseHeaders.map((header) => header.name.toLowerCase());
  const setCookie = responseHeaders
    .filter((header) => header.name.toLowerCase() === "set-cookie")
    .map((header) => header.value)
    .join("\n");
  expect(backResponse!.headers()["cache-control"]).toContain("no-store");
  expect(backResponse!.headers()["location"]).toBeUndefined();
  expect(setCookie).not.toMatch(
    /(?:__Host-session|session|__Host-auth_sid|auth_sid|__Host-auth_access|auth_access|__Host-auth_refresh|auth_refresh)=/iu,
  );
  expect(headerNames).not.toContain("secure-session-challenge");
  expect(headerNames).not.toContain("secure-session-registration");
  expect(headerNames).not.toContain("sec-session-challenge");
  expect(headerNames).not.toContain("sec-session-registration");
  await expect(
    page.getByText("この画面は古くなっています。最初からやり直してください。"),
  ).toBeVisible();

  await page.goForward({ waitUntil: "domcontentloaded" });
  await expect(page.locator('input[name="client_email[pass_code]"]')).toBeVisible();
  await page.locator("form").nth(1).getByRole("button").click();
  await expect(page).toHaveURL(/\/sign\/up\?ri=jp/u);
});

test("browser Back after APP sign-in Email OTP refuses the Flow-less address entry", async ({
  page,
  context,
}) => {
  test.setTimeout(90_000);
  const rubyFixture = `
require Rails.root.join("test/support/oidc_test_entry").to_s
address = "history-sign-in-#{SecureRandom.hex(12)}@example.test"
client = Client.create!(
  security_mode_id: SecurityModeConfigurable::NORMAL,
  status_id: ClientStatus::ACTIVE,
  birthdate: Date.new(1990, 1, 1),
)
contact = client.client_emails.create!(
  address:, user_email_status_id: ClientEmailStatus::VERIFIED,
)
contact.finalize_binding!
issuance = OidcTestEntry.issue!(
  surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
)
binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
auth_session, raw_sid = ClientAuthCeremonySession.issue!
binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
  reference: issuance.reference, surface: "app", expected_intent: "sign_in", binding:, raw_auth_sid: raw_sid,
)
admitted_session, admitted_sid = ClientAuthCeremonySession.rotate_and_admit!(
  admission_purpose: payload.fetch("purpose"), previous_raw_sid: raw_sid,
  authorization_transaction_ref: issuance.transaction.transaction_id, expires_at: binding.expires_at,
)
binding.redeem!(auth_session:, admitted_auth_session: admitted_session)
cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
STDOUT.write([cookie_name, admitted_sid, address].join(9.chr) + 10.chr)
`;
  const fixtureOutput = execFileSync("bundle", ["exec", "bin/rails", "runner", "-"], {
    encoding: "utf8",
    input: rubyFixture,
    env: {
      ...process.env,
      RAILS_ENV: "test",
      RACK_ENV: "test",
      UMAXICA_RUNTIME_ROLE: "shared",
      VALKEY_NAMESPACE_WORKER_ID: "browser",
    },
  });
  const fixtureLine = fixtureOutput.trimEnd().split("\n").pop();
  expect(fixtureLine).toBeDefined();
  const [cookieName, rawSid, emailAddress] = fixtureLine!.split("\t");
  expect(cookieName).toBeTruthy();
  expect(rawSid).toBeTruthy();
  expect(emailAddress).toContain("@example.test");
  await context.addCookies([
    {
      name: cookieName!,
      value: rawSid!,
      url: railsOrigin,
      httpOnly: true,
      secure: cookieName!.startsWith("__Host-"),
      sameSite: "Lax",
    },
  ]);

  await page.goto(`${railsOrigin}/sign/in?ri=jp`);
  await page.locator('a[href*="/sign/in/email/new"]').click();
  await page.locator('input[name="client_email[address]"]').fill(emailAddress!);
  await expect(page.locator('input[name="cf-turnstile-response"]')).toHaveValue("e2e-turnstile");
  const emailEntryUrl = page.url();
  const otpStep = page.waitForURL((url) => url.pathname.includes("/sign/in/email/edit"), {
    waitUntil: "domcontentloaded",
  });
  await page.locator("form button[type=submit]").click();
  await otpStep;
  await expect(page.locator('input[name="client_email[pass_code]"]')).toBeVisible();

  const phaseRefusal = await page.goBack({ waitUntil: "domcontentloaded" });
  expect(phaseRefusal).not.toBeNull();
  expect(phaseRefusal!.request().method()).toBe("GET");
  expect(phaseRefusal!.status()).toBe(409);
  expect(page.url()).toBe(emailEntryUrl);
  expect(await phaseRefusal!.text()).toBe(
    "この画面は古くなっています。最初からやり直してください。",
  );
  const responseHeaders = await phaseRefusal!.headersArray();
  const headerNames = responseHeaders.map((header) => header.name.toLowerCase());
  const setCookie = responseHeaders
    .filter((header) => header.name.toLowerCase() === "set-cookie")
    .map((header) => header.value)
    .join("\n");
  expect(phaseRefusal!.headers()["cache-control"]).toContain("no-store");
  expect(phaseRefusal!.headers()["location"]).toBeUndefined();
  expect(setCookie).not.toMatch(
    /(?:__Host-session|session|__Host-auth_sid|auth_sid|__Host-auth_access|auth_access|__Host-auth_refresh|auth_refresh)=/iu,
  );
  expect(headerNames).not.toContain("secure-session-challenge");
  expect(headerNames).not.toContain("secure-session-registration");
  expect(headerNames).not.toContain("sec-session-challenge");
  expect(headerNames).not.toContain("sec-session-registration");
  await page.goForward({ waitUntil: "domcontentloaded" });
  await expect(page.locator('input[name="client_email[pass_code]"]')).toBeVisible();
});
