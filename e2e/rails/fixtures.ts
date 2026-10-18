import { expect, test as base } from "playwright/test";

import { railsOrigin } from "./settings";

// Apply the boundary before any page/popup exists. No response content is mocked. Fetching with
// zero redirects lets us reject a Location before Chromium can follow it (redirect hops can
// otherwise bypass Playwright route callbacks). This public-page suite permits no redirects.
export const test = base.extend({
  context: async ({ context }, use) => {
    const violations: string[] = [];
    context.on("page", (page) => {
      page.on("pageerror", (error) => violations.push(`Browser JavaScript error: ${error.name}`));
    });
    await context.route("**/*", async (route) => {
      const request = route.request();
      const { origin } = new URL(request.url());
      if (
        request.resourceType() === "script" &&
        request.url() === "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
      ) {
        // The shared shell requests this provider even on the public landing. Abort the real
        // request; do not simulate Turnstile. No ceremony is exercised by this suite.
        base.info().annotations.push({
          type: "blocked-dependency",
          description: "Turnstile bootstrap blocked; public landing has no provider prerequisite",
        });
        await route.abort("blockedbyclient");
        return;
      }
      if (origin !== railsOrigin) {
        violations.push(`Blocked browser origin: ${origin}`);
        await route.abort("blockedbyclient");
        return;
      }
      const localUrl = new URL(request.url());
      localUrl.hostname = "127.0.0.1";
      const response = await route.fetch({
        url: localUrl.href,
        headers: { ...request.headers(), host: new URL(railsOrigin).host },
        maxRedirects: 0,
      });
      if (response.status() >= 300 && response.status() < 400) {
        violations.push(`Blocked HTTP redirect: ${response.status()}`);
        await route.abort("blockedbyclient");
        return;
      }
      if (response.status() >= 400) {
        violations.push(`Local HTTP failure: ${response.status()}`);
      }
      await route.fulfill({ response });
    });
    await context.routeWebSocket("**/*", async (socket) => {
      violations.push("Blocked browser WebSocket");
      await socket.close();
    });
    await use(context);
    expect(violations, "Browser must render without JavaScript, HTTP or egress errors").toEqual([]);
  },
});
export { expect } from "playwright/test";
