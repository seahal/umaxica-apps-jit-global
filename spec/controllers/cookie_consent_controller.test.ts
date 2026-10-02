// The cookie consent banner on the surfaces that do not boot React.
import { beforeEach, describe, expect, it, vi } from "vitest";

import CookieConsentController from "@/controllers/cookie_consent_controller";

import { requireElement } from "../support/dom";
import { recordEvents } from "../support/events";
import { jsonResponse, requestBody, requestWithMethod } from "../support/http";
import { mountController } from "../support/stimulus";

const markup = (consented = false) => `
  <div data-controller="cookie-consent"
       data-cookie-consent-consented-value="${consented}"
       data-cookie-consent-endpoint-value="/api/v0/preferences/cookie">
    <div data-cookie-consent-target="banner" class="hidden">
      <button type="button" data-action="cookie-consent#accept">Accept</button>
      <button type="button" data-action="cookie-consent#reject">Reject</button>
    </div>
  </div>
`;

const mount = (html = markup()) =>
  mountController<CookieConsentController>("cookie-consent", CookieConsentController, html);

const banner = (element: HTMLElement) =>
  requireElement(element, "[data-cookie-consent-target='banner']");

let announced: ReturnType<typeof recordEvents>;

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  announced = recordEvents(globalThis, "consentChanged");
});

describe("CookieConsentController", () => {
  describe("connect", () => {
    it("shows the banner to a visitor who has not consented", async () => {
      const { element } = await mount();

      expect(banner(element).classList.contains("hidden")).toBe(false);
    });

    it("leaves the banner hidden for a visitor who already consented", async () => {
      const { element } = await mount(markup(true));

      expect(banner(element).classList.contains("hidden")).toBe(true);
    });
  });

  describe("accept", () => {
    it("records every consent the banner offers and hides itself", async () => {
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ preference: { consented: true } }));
      vi.stubGlobal("fetch", fetchMock);
      const { controller, element } = await mount();

      await controller.accept(new Event("click"));

      expect(requestWithMethod(fetchMock, "PATCH")?.url).toBe("/api/v0/preferences/cookie");
      expect(requestBody(fetchMock)).toEqual({
        preference_cookie: {
          consented: true,
          functional: true,
          performant: true,
          // Never granted by the banner: it is the one category the visitor must ask for.
          targetable: false,
        },
      });
      expect(banner(element).classList.contains("hidden")).toBe(true);
    });

    it("announces the stored preference so the rest of the page can follow it", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ preference: { consented: true } })),
      );
      const { controller } = await mount();

      await controller.accept(new Event("click"));

      expect(announced.detail()).toEqual({ consented: true });
    });

    it("stops the button from following its own default", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({})));
      const { controller } = await mount();
      const event = new Event("click", { cancelable: true });

      await controller.accept(event);

      expect(event.defaultPrevented).toBe(true);
    });
  });

  describe("reject", () => {
    it("records a refusal of every optional category", async () => {
      const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}));
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.reject(new Event("click"));

      expect(requestBody(fetchMock)).toEqual({
        preference_cookie: {
          consented: false,
          functional: false,
          performant: false,
          targetable: false,
        },
      });
    });
  });

  describe("when the preference cannot be stored", () => {
    it("reports a refusal and leaves the banner up", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 500)));
      const { controller, element } = await mount();
      const errors = recordEvents(element, "cookie-consent:error");

      await controller.accept(new Event("click"));

      expect(errors.detail()).toMatchObject({
        message: "Consent update failed",
        status: 500,
      });
      expect(banner(element).classList.contains("hidden")).toBe(false);
    });

    it("reports a request that never reached the server", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockRejectedValue(new Error("offline")));
      const { controller, element } = await mount();
      const errors = recordEvents(element, "cookie-consent:error");

      await controller.accept(new Event("click"));

      expect(errors.detail()).toMatchObject({ message: "Consent update error" });
    });
  });
});
