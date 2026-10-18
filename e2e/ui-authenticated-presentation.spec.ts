import { execFileSync } from "node:child_process";

import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Established-session fixtures exercise ordinary admission and rendering, not login issuance.
// Cookies remain in memory. Retained traces can expose test credentials, so this file disables them.
test.use({ trace: "off" });

type Fixture = {
  cookie: string;
  sessions: { model: string; id: number }[];
  access: Record<string, string>;
  visitor_verification: string;
};
let fixture: Fixture = { cookie: "", visitor_verification: "", sessions: [], access: {} };

test.beforeAll(() => {
  const payload: unknown = JSON.parse(
    execFileSync(
      "bin/rails",
      [
        "runner",
        "-e",
        "test",
        `abort 'test required' unless Rails.env.test?
client = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: '2000-01-01')
client_token = ClientToken.create!(user: client, root_login_established_at: Time.current, established_authentication_method: 'passkey')
visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, birthdate: '2000-01-01')
visitor_token = VisitorToken.create!(visitor: visitor, root_login_established_at: Time.current)
visitor_token.update!(last_step_up_at: Time.current, last_step_up_scope: 'settings_email', last_step_up_aal: 'aal2', last_step_up_method: 'passkey', last_step_up_session_public_id: visitor_token.public_id, last_step_up_purpose: 'step_up', last_step_up_audience: 'step_up:com')
verification_record, verification_cookie = VisitorVerification.issue_for_token!(token: visitor_token)
operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
operator_token = OperatorToken.create!(staff: operator, root_login_established_at: Time.current)
access = {}
[['base.app.localhost', client, client_token, 'client', 'BASE_APP'],
 ['auth.app.localhost', client, client_token, 'client', 'AUTH_APP'],
 ['base.com.localhost', visitor, visitor_token, 'visitor', 'BASE_COM'],
 ['edit.org.localhost', operator, operator_token, 'operator', 'AUTH_ORG']].each do |host, actor, token, resource, issuer|
 access[host] = AuthenticationToken.encode(actor, host: host, session_public_id: token.public_id, resource_type: resource, jwt_issuer_id: "surface:#{issuer}")
end
STDOUT.write({cookie: AuthenticationBase::ACCESS_COOKIE_KEY, sessions: [{model: 'ClientToken', id: client_token.id}, {model: 'VisitorToken', id: visitor_token.id}, {model: 'OperatorToken', id: operator_token.id}], access: access, visitor_verification: "#{VisitorVerification.cookie_name}=#{verification_cookie}"}.to_json)`,
      ],
      { encoding: "utf8" },
    ),
  );
  if (typeof payload !== "object" || payload === null) {
    throw new Error("The session fixture payload is missing.");
  }
  const cookie: unknown = Reflect.get(payload, "cookie");
  const verification: unknown = Reflect.get(payload, "visitor_verification");
  const access: unknown = Reflect.get(payload, "access");
  const sessions: unknown = Reflect.get(payload, "sessions");
  if (
    typeof cookie !== "string" ||
    typeof verification !== "string" ||
    typeof access !== "object" ||
    access === null ||
    !Array.isArray(sessions)
  ) {
    throw new Error("The session fixture payload has an invalid shape.");
  }
  const sessionRows: unknown[] = sessions;
  const parsedSessions: Fixture["sessions"] = [];
  for (const row of sessionRows) {
    if (typeof row !== "object" || row === null) {
      throw new Error("A fixture session row is missing.");
    }
    const model: unknown = Reflect.get(row, "model");
    const id: unknown = Reflect.get(row, "id");
    if (
      typeof model !== "string" ||
      !["ClientToken", "VisitorToken", "OperatorToken"].includes(model) ||
      typeof id !== "number" ||
      !Number.isSafeInteger(id) ||
      id <= 0
    ) {
      throw new Error("A fixture session reference is invalid.");
    }
    parsedSessions.push({ model, id });
  }
  const parsedAccess: Fixture["access"] = {};
  for (const host of [
    "base.app.localhost",
    "auth.app.localhost",
    "base.com.localhost",
    "edit.org.localhost",
  ]) {
    const value: unknown = Reflect.get(access, host);
    if (typeof value !== "string" || value.length === 0) {
      throw new Error("A fixture host credential is missing.");
    }
    parsedAccess[host] = value;
  }
  fixture = {
    cookie,
    visitor_verification: verification,
    sessions: parsedSessions,
    access: parsedAccess,
  };
});

test.afterAll(() => {
  if (fixture.sessions.length > 0) {
    execFileSync(
      "bin/rails",
      [
        "runner",
        "-e",
        "test",
        fixture.sessions.map(({ model, id }) => `${model}.find(${id}).revoke!`).join("\n"),
      ],
      { stdio: "pipe" },
    );
  }
});

const journeys = [
  { host: "base.app.localhost", path: "/identity", heading: "Identity" },
  { host: "base.app.localhost", path: "/identity/emails", heading: null },
  { host: "base.app.localhost", path: "/secrets", heading: null },
  { host: "base.app.localhost", path: "/sign/out/edit", heading: null },
  { host: "auth.app.localhost", path: "/settings/passkeys", heading: "Passkeys" },
  { host: "auth.app.localhost", path: "/settings/totps", heading: "Totps" },
  { host: "base.com.localhost", path: "/identity/emails", heading: null },
  { host: "base.com.localhost", path: "/identity/secrets", heading: null },
  { host: "edit.org.localhost", path: "/dashboard", heading: "Publishing" },
  { host: "edit.org.localhost", path: "/publishing/docs/app/entries", heading: null },
  { host: "edit.org.localhost", path: "/publishing/docs/app/entries/new", heading: null },
];

const presentations = [
  ...[320, 768, 1024, 1440].map((width) => ({
    width,
    language: "en",
    theme: "light",
    code: "li",
    os: "light" as const,
  })),
  { width: 320, language: "ja", theme: "dark", code: "dr", os: "light" as const },
  { width: 320, language: "en", theme: "system", code: "sy", os: "dark" as const },
  { width: 1440, language: "ja", theme: "system", code: "sy", os: "light" as const },
];
for (const journey of journeys) {
  for (const presentation of presentations) {
    const { width, language, theme, code, os } = presentation;
    test(`${journey.host}${journey.path} has readable authenticated presentation at ${width}px in ${language}/${theme}/OS-${os}`, async ({
      browser,
    }) => {
      const context = await browser.newContext({
        viewport: { width, height: 900 },
        colorScheme: os,
        reducedMotion: "reduce",
      });
      try {
        const accessToken = fixture.access[journey.host];
        // oxlint-disable-next-line vitest/no-conditional-in-test -- reject a missing fixture prerequisite without exposing credentials.
        if (!accessToken) {
          throw new Error("The fixture host credential is missing.");
        }
        const separator = fixture.visitor_verification.indexOf("=");
        await context.addCookies([
          {
            name: fixture.cookie,
            value: accessToken,
            url: `http://${journey.host}:3188`,
            httpOnly: true,
          },
          { name: "ct", value: code, url: `http://${journey.host}:3188` },
          {
            name: fixture.visitor_verification.slice(0, separator),
            value: fixture.visitor_verification.slice(separator + 1),
            url: `http://${journey.host}:3188`,
            httpOnly: true,
          },
        ]);
        const page = await context.newPage();
        await page.route("**/*", (route) => {
          // oxlint-disable-next-line vitest/no-conditional-in-test
          return new URL(route.request().url()).hostname === journey.host
            ? route.continue()
            : route.abort();
        });
        const response = await page.goto(
          `http://${journey.host}:3188${journey.path}?ri=jp&lx=${language}`,
        );
        expect(response?.status()).toBe(200);
        const title = page.getByRole("main").getByRole("heading", { level: 1 });
        await expect(title).toBeVisible();
        await expect(page.locator("html")).toHaveAttribute("data-theme", theme);
        // oxlint-disable-next-line vitest/no-conditional-in-test
        if (journey.heading) {
          await expect(title).toHaveText(journey.heading);
        }
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
        // Only synthetic test data is present; do not visit/reveal one-time secrets.
        await page.screenshot({
          path: `/tmp/umaxica-ui-normalization-continuation/${journey.host}-${journey.path.replaceAll("/", "-")}-${width}-${language}-${theme}-OS-${os}.png`,
          fullPage: true,
        });
      } finally {
        await context.close();
      }
    });
  }
}
