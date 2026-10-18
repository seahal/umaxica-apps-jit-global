// The cookie preference form on the surfaces that do not boot React.
import { beforeEach, describe, expect, it, vi } from "vitest";

import CookieToggleController from "@/controllers/cookie_toggle_controller";

import { requireInput } from "../support/dom";
import { jsonResponse, requestUrl } from "../support/http";
import { mountController } from "../support/stimulus";

const MARKUP = `
  <div data-controller="cookie-toggle" data-cookie-toggle-endpoint-url-value="/api/v0/preferences/cookie">
    <form>
      <input type="checkbox" data-cookie-toggle-target="checkbox"
             name="preference_cookie[functional]">
      <input type="checkbox" data-cookie-toggle-target="checkbox"
             name="preference_cookie[performant]" checked>
      <input type="checkbox" data-cookie-toggle-target="checkbox"
             name="preference_cookie[targetable]">
      <input type="checkbox" data-cookie-toggle-target="checkbox"
             name="preference_cookie[consented]">
    </form>
    <p data-cookie-toggle-target="status"></p>
  </div>
`;

const mount = (html = MARKUP) =>
  mountController<CookieToggleController>("cookie-toggle", CookieToggleController, html);

const statusText = (element: HTMLElement) =>
  element.querySelector("[data-cookie-toggle-target='status']")?.textContent ?? null;

const checkbox = (element: HTMLElement, field: string) =>
  element.querySelector<HTMLInputElement>(`input[name="preference_cookie[${field}]"]`);

const submitEnd = (success: boolean) =>
  new CustomEvent("turbo:submit-end", { detail: { success } });

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  vi.stubGlobal("fetch", vi.fn<typeof fetch>());
});

describe("CookieToggleController", () => {
  describe("the status line", () => {
    it("counts the categories the visitor has enabled", async () => {
      const { element } = await mount();

      expect(statusText(element)).toBe("1 / 4 cookies enabled");
    });

    it("recounts when a box is toggled", async () => {
      const { controller, element } = await mount();
      requireInput(element, 'input[name="preference_cookie[functional]"]').checked = true;

      controller.toggle(new Event("change"));

      expect(statusText(element)).toBe("2 / 4 cookies enabled");
    });

    it("does nothing when the markup carries no status line", async () => {
      const { controller } = await mount(
        MARKUP.replace('<p data-cookie-toggle-target="status"></p>', ""),
      );

      expect(() => controller.updateStatus()).not.toThrow();
    });
  });

  describe("after the form is saved", () => {
    it("re-reads the stored preference and reflects it into the boxes", async () => {
      vi.stubGlobal(
        "fetch",
        vi
          .fn<typeof fetch>()
          .mockResolvedValue(jsonResponse({ functional: true, performant: false })),
      );
      const { controller, element } = await mount();

      await controller.onFormSubmitEnd(submitEnd(true));

      expect(checkbox(element, "functional")?.checked).toBe(true);
      expect(checkbox(element, "performant")?.checked).toBe(false);
      expect(statusText(element)).toBe("1 / 4 cookies enabled");
    });

    it("leaves a category the server did not mention alone", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ functional: true })),
      );
      const { controller, element } = await mount();

      await controller.onFormSubmitEnd(submitEnd(true));

      expect(checkbox(element, "performant")?.checked).toBe(true);
    });

    it("ignores a value that is not a yes or a no", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ functional: "yes" })),
      );
      const { controller, element } = await mount();

      await controller.onFormSubmitEnd(submitEnd(true));

      expect(checkbox(element, "functional")?.checked).toBe(false);
    });

    it("does nothing when the submission failed", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.onFormSubmitEnd(submitEnd(false));

      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("does nothing when the event carries no outcome", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      await controller.onFormSubmitEnd(new Event("turbo:submit-end"));

      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("keeps the status line current when the preference cannot be re-read", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockRejectedValue(new Error("offline")));
      const { controller, element } = await mount();

      await controller.onFormSubmitEnd(submitEnd(true));

      expect(statusText(element)).toBe("1 / 4 cookies enabled");
    });

    it("leaves the boxes alone when the server answers no preference at all", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse(null)));
      const { controller, element } = await mount();

      await controller.onFormSubmitEnd(submitEnd(true));

      expect(checkbox(element, "performant")?.checked).toBe(true);
    });

    it("treats an error status as a preference it could not read", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 500)));
      const { controller, element } = await mount();

      await controller.onFormSubmitEnd(submitEnd(true));

      expect(statusText(element)).toBe("1 / 4 cookies enabled");
    });
  });

  describe("the form listener", () => {
    it("re-reads the preference when the form reports a save", async () => {
      const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ functional: true }));
      vi.stubGlobal("fetch", fetchMock);
      const { element } = await mount();

      element.querySelector("form")?.dispatchEvent(submitEnd(true));
      await vi.waitFor(() => expect(fetchMock).toHaveBeenCalled());

      expect(new URL(requestUrl(fetchMock)).pathname).toBe("/api/v0/preferences/cookie");
    });

    it("refuses to re-read when the layout declared no endpoint", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount(
        MARKUP.replace(' data-cookie-toggle-endpoint-url-value="/api/v0/preferences/cookie"', ""),
      );

      await expect(controller.onFormSubmitEnd(submitEnd(true))).rejects.toThrow(
        /endpoint-url-value/u,
      );
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("does nothing when the markup carries no form", async () => {
      const { controller } = await mount(`<div data-controller="cookie-toggle"></div>`);

      expect(() => controller.setupFormListener()).not.toThrow();
    });
  });
});
