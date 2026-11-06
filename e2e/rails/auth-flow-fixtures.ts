import { expect, test as base } from "playwright/test";

import { railsOrigin } from "./settings";

const turnstileScript = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
const localTurnstileApi = `
  window.turnstile = {
    render(_container, options) {
      window.setTimeout(() => options.callback("e2e-turnstile"), 0);
      return "e2e-widget";
    },
    execute() {},
    remove() {},
  };
`;

// This journey allows same-origin Rails redirects and one explicit local Turnstile substitute.
// Every other browser origin stays blocked; response bodies are always fetched from Rails.
export const test = base.extend({
  context: async ({ context }, use) => {
    const violations: string[] = [];
    context.on("page", (page) => {
      page.on("pageerror", (error) => violations.push(`Browser JavaScript error: ${error.name}`));
    });
    await context.route("**/*", async (route) => {
      const request = route.request();
      const requestedUrl = new URL(request.url());
      if (request.url() === turnstileScript) {
        await route.fulfill({
          status: 200,
          contentType: "application/javascript",
          body: localTurnstileApi,
        });
        return;
      }
      if (requestedUrl.origin !== railsOrigin) {
        violations.push(`Blocked browser origin: ${requestedUrl.origin}`);
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
      const status = response.status();
      const expectedPhaseRefusal =
        request.method() === "GET" &&
        ["/sign/in/email/new", "/sign/up/email/new"].includes(requestedUrl.pathname) &&
        status === 409;
      if (status >= 300 && status < 400) {
        const { location } = response.headers();
        if (!location || new URL(location, request.url()).origin !== railsOrigin) {
          violations.push(`Blocked external or missing redirect target: ${status}`);
          await route.abort("blockedbyclient");
          return;
        }
      } else if (status >= 400 && !expectedPhaseRefusal) {
        violations.push(
          `Local HTTP failure: ${status} ${request.method()} ${requestedUrl.pathname}`,
        );
      }
      await route.fulfill({ response });
    });
    await context.routeWebSocket("**/*", async (socket) => {
      violations.push("Blocked browser WebSocket");
      await socket.close();
    });
    await use(context);
    expect(
      violations,
      "Browser journey must stay local and report only its asserted phase refusal",
    ).toEqual([]);
  },
});

export { expect } from "playwright/test";
