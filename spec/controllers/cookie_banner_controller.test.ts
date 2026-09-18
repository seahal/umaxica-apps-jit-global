// The dismissible cookie banner on the surfaces that do not boot React.
import { beforeEach, describe, expect, it, vi } from "vitest";

import CookieBannerController from "@/controllers/cookie_banner_controller";

import { recordEvents } from "../support/events";
import { jsonResponse, noContentResponse, requestUrl, requestWithMethod } from "../support/http";
import { mountController } from "../support/stimulus";

const MARKUP = `
  <div data-controller="cookie-banner" data-cookie-banner-settings-url-value="/preferences/cookies">
    <button type="button" data-action="cookie-banner#accept">Accept</button>
    <button type="button" data-action="cookie-banner#reject">Reject</button>
    <button type="button" data-action="cookie-banner#invisible">Close</button>
    <button type="button" data-action="cookie-banner#openSettings">Settings</button>
  </div>
  <div data-controller="cookie-toggle">
    <form>
      <input type="checkbox" name="preference_cookie[consented]">
      <input type="checkbox" name="preference_cookie[functional]">
      <input type="checkbox" name="preference_cookie[performant]">
      <input type="checkbox" name="preference_cookie[targetable]">
    </form>
  </div>
`;

const mount = (html = MARKUP) =>
  mountController<CookieBannerController>("cookie-banner", CookieBannerController, html);

const bannerIsOnPage = () => document.querySelector("[data-controller~='cookie-banner']") !== null;

// `connect` reads the stored preference before anything else, so a spec about what a button does
// answers that first request as "not consented yet" and asserts on the PATCH that follows.
const consentBox = (field: string) =>
  document.querySelector<HTMLInputElement>(`input[name="preference_cookie[${field}]"]`);

let assign: ReturnType<typeof vi.fn>;

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  assign = vi.fn();
  vi.stubGlobal("location", {
    origin: "http://localhost:3000",
    search: "?ri=us&lx=en&ct=dr&unrelated=1",
    assign,
  });
});

describe("CookieBannerController", () => {
  describe("connect", () => {
    it("removes itself for a visitor who already consented", async () => {
      // Fresh Response per call: a shared mockResolvedValue Response can only be .json()'d once,
      // and connect() already consumes the body before this assertion runs.
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockImplementation(() => Promise.resolve(jsonResponse({ show_banner: false })));
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.checkConsentState();

      expect(bannerIsOnPage()).toBe(false);
    });

    it("accepts through the button the banner exposes", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { element } = await mount();

      element.querySelector<HTMLButtonElement>("[data-action='cookie-banner#accept']")?.click();
      await Promise.resolve();
      await Promise.resolve();

      expect(requestWithMethod(fetchMock, "PATCH")?.body).toEqual({
        cookie: { consented: true, functional: true, performant: true, targetable: true },
      });
    });

    it("skips a named decision whose checkbox is absent", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount(`
        <div data-controller="cookie-banner">
          <button type="button" data-action="cookie-banner#accept">Accept</button>
        </div>
        <div data-controller="cookie-toggle">
          <form></form>
        </div>
      `);

      await controller.submitConsent(true);

      expect(requestWithMethod(fetchMock, "PATCH")).toBeDefined();
    });

    it("skips preference fields the stored decision does not name", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      controller.syncCookieFormConsent({ consented: true });

      expect(consentBox("consented")?.checked).toBe(true);
    });

    it("does nothing when there is no cookie-toggle form to sync", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount(`
        <div data-controller="cookie-banner">
          <button type="button" data-action="cookie-banner#accept">Accept</button>
        </div>
      `);

      await controller.submitConsent(true);

      expect(requestWithMethod(fetchMock, "PATCH")).toBeDefined();
    });

    it("stays for a visitor who has not consented", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ show_banner: true })),
      );
      const { controller } = await mount();

      await controller.checkConsentState();

      expect(bannerIsOnPage()).toBe(true);
    });

    it("stays when the stored preference cannot be read", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockRejectedValue(new Error("offline")));
      const { controller } = await mount();

      await controller.checkConsentState();

      expect(bannerIsOnPage()).toBe(true);
    });

    it("stays when the endpoint answers an error status", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 500)));
      const { controller } = await mount();

      await controller.checkConsentState();

      expect(bannerIsOnPage()).toBe(true);
    });
  });

  describe("the endpoint it talks to", () => {
    it("carries the surface query parameters and nothing else", async () => {
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ show_banner: true }));
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.checkConsentState();

      const url = new URL(requestUrl(fetchMock));
      expect(url.pathname).toBe("/web/v0/cookie");
      expect(url.searchParams.get("ri")).toBe("us");
      expect(url.searchParams.get("ct")).toBe("dr");
      expect(url.searchParams.has("unrelated")).toBe(false);
    });
  });

  // `PreferenceWebCookieActions#update` answers 204 with no body, so every write below is answered
  // the way the server actually answers it. Parsing that response threw, which left the banner on
  // screen after the decision had already been stored.
  describe("accept", () => {
    it("reports a failed accept instead of removing the banner", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(jsonResponse({}, 500));
      vi.stubGlobal("fetch", fetchMock);
      const { element } = await mount();
      const events = recordEvents(element, "cookie-banner:error");

      element.querySelector<HTMLButtonElement>("[data-action='cookie-banner#accept']")?.click();
      await Promise.resolve();
      await Promise.resolve();

      expect(bannerIsOnPage()).toBe(true);
      expect(events.events).toHaveLength(1);
    });

    it("records consent for every category and removes the banner", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.submitConsent(true);

      expect(requestWithMethod(fetchMock, "PATCH")?.body).toEqual({
        cookie: { consented: true, functional: true, performant: true, targetable: true },
      });
      expect(bannerIsOnPage()).toBe(false);
    });

    it("reflects the stored decision into the preference form on the same page", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.submitConsent(true);

      expect(consentBox("consented")?.checked).toBe(true);
      expect(consentBox("functional")?.checked).toBe(true);
      expect(consentBox("performant")?.checked).toBe(true);
      expect(consentBox("targetable")?.checked).toBe(true);
    });
  });

  describe("reject", () => {
    it("still records that a choice was made, but grants nothing", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      fetchMock.mockResolvedValueOnce(jsonResponse({ show_banner: true }));
      fetchMock.mockResolvedValue(noContentResponse());
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.submitConsent(false);

      expect(requestWithMethod(fetchMock, "PATCH")?.body).toEqual({
        cookie: { consented: true, functional: false, performant: false, targetable: false },
      });
      expect(bannerIsOnPage()).toBe(false);
      expect(consentBox("consented")?.checked).toBe(true);
      expect(consentBox("functional")?.checked).toBe(false);
    });

    it("reports a refusal the server would not store", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 500)));
      const { controller, element } = await mount();
      const errors = recordEvents(element, "cookie-banner:error");

      controller.reject(new Event("click"));
      await vi.waitFor(() => expect(errors.events).toHaveLength(1));

      expect(errors.events[0]?.detail).toMatchObject({ message: "Cookie consent update failed" });
      expect(bannerIsOnPage()).toBe(true);
    });
  });

  describe("invisible", () => {
    it("removes the banner without recording anything", async () => {
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ show_banner: true }));
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      controller.invisible(new Event("click"));

      expect(bannerIsOnPage()).toBe(false);
      expect(requestWithMethod(fetchMock, "PATCH")).toBeUndefined();
    });
  });

  describe("openSettings", () => {
    it("navigates to the settings screen the markup names", async () => {
      const { controller } = await mount();

      controller.openSettings(new Event("click"));

      expect(assign).toHaveBeenCalledWith("/preferences/cookies");
    });

    it("asks the page to open its own settings when the markup names none", async () => {
      const { controller, element } = await mount(
        MARKUP.replace('data-cookie-banner-settings-url-value="/preferences/cookies"', ""),
      );
      const opened = recordEvents(element, "cookie-banner:open-settings");

      controller.openSettings(new Event("click"));

      expect(opened.events).toHaveLength(1);
      expect(assign).not.toHaveBeenCalled();
    });
  });
});
