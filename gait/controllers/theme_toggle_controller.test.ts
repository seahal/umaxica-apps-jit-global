// The theme toggle buttons on the surfaces that do not boot React.
//
// This controller reports a choice to the preference endpoint and announces the result; applying
// the theme to the document is `theme_controller`'s job, not this one's.
import { beforeEach, describe, expect, it, vi } from "vitest";

import ThemeToggleController from "@/controllers/theme_toggle_controller";

import { requireElement } from "../support/dom";
import { recordEvents } from "../support/events";
import { jsonResponse, requestUrl, requestWithMethod } from "../support/http";
import { mountController } from "../support/stimulus";

const MARKUP = `
  <div data-controller="theme-toggle"
       data-theme-toggle-current-value="sy"
       data-theme-toggle-endpoint-value="/preferences/theme">
    <button type="button" data-theme="dr">Dark</button>
    <button type="button" data-theme="li">Light</button>
  </div>
`;

const mount = (html = MARKUP) =>
  mountController<ThemeToggleController>("theme-toggle", ThemeToggleController, html);

function toggleEvent(target: Element): Event {
  const event = new Event("click");
  Object.defineProperty(event, "currentTarget", { value: target });
  return event;
}

let announced: ReturnType<typeof recordEvents>;

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  announced = recordEvents(globalThis, "themeChanged");
});

describe("ThemeToggleController", () => {
  describe("toggle", () => {
    it("reports a new choice to the endpoint", async () => {
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ preference: { ct: "dr" } }));
      vi.stubGlobal("fetch", fetchMock);
      const { controller, element } = await mount();

      await controller.updateTheme("dr");

      expect(requestUrl(fetchMock)).toBe("/preferences/theme");
      expect(requestWithMethod(fetchMock, "PATCH")?.body).toEqual({
        preference_theme: { option_id: "dr" },
      });
      expect(controller.currentTheme).toBe("dr");
      expect(element).toBeTruthy();
    });

    it("reads the theme from the button the visitor pressed", async () => {
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ preference: { ct: "dr" } }));
      vi.stubGlobal("fetch", fetchMock);
      const { controller, element } = await mount();
      controller.toggle(toggleEvent(requireElement(element, "[data-theme='dr']")));

      expect(fetchMock).toHaveBeenCalled();
    });

    it("does nothing when the event is not from an element", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      controller.toggle(new Event("click"));

      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("does nothing when the visitor presses the theme already in force", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      vi.stubGlobal("fetch", fetchMock);
      const { controller, element } = await mount();
      controller.currentTheme = "dr";

      controller.toggle(toggleEvent(requireElement(element, "[data-theme='dr']")));

      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("does nothing when the pressed control names no theme", async () => {
      const fetchMock = vi.fn<typeof fetch>();
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      controller.toggle(toggleEvent(document.createElement("button")));

      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("falls back to a radio's value when it carries no data-theme", async () => {
      const fetchMock = vi
        .fn<typeof fetch>()
        .mockResolvedValue(jsonResponse({ preference: { ct: "li" } }));
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mount();

      const radio = document.createElement("input");
      radio.type = "radio";
      radio.value = "li";
      controller.toggle(toggleEvent(radio));

      expect(fetchMock).toHaveBeenCalled();
    });
  });

  describe("updateTheme", () => {
    it("adopts the theme the server stored when it differs", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ preference: { ct: "li" } })),
      );
      const { controller } = await mount();

      await controller.updateTheme("dr");

      expect(controller.currentTheme).toBe("li");
    });

    it("keeps the requested theme when the server names none", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ preference: {} })),
      );
      const { controller } = await mount();

      await controller.updateTheme("dr");

      expect(controller.currentTheme).toBe("dr");
    });

    it("announces the change so the rest of the page can follow it", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ preference: { ct: "dr" } })),
      );
      const { controller } = await mount();

      await controller.updateTheme("dr");

      expect(announced.detail()).toEqual({ ct: "dr" });
    });

    it("announces the requested theme when the server sends no preference", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({})));
      const { controller } = await mount();

      await controller.updateTheme("dr");

      expect(announced.detail()).toEqual({ ct: "dr" });
    });

    it("reports a refusal rather than pretending the theme changed", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 500)));
      const { controller } = await mount();
      const errors = recordEvents(controller.element, "theme-toggle:error");

      await controller.updateTheme("dr");

      expect(errors.detail()).toMatchObject({ message: "Theme update failed", status: 500 });
      expect(controller.currentTheme).toBe("sy");
    });

    it("reports a request that never reached the server", async () => {
      vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockRejectedValue(new Error("offline")));
      const { controller } = await mount();
      const errors = recordEvents(controller.element, "theme-toggle:error");

      await controller.updateTheme("dr");

      expect(errors.detail()).toMatchObject({ message: "Theme update error" });
    });
  });

  describe("connect", () => {
    it("starts from the theme the markup declares", async () => {
      const { controller } = await mount(
        MARKUP.replace(
          'data-theme-toggle-current-value="sy"',
          'data-theme-toggle-current-value="dr"',
        ),
      );

      expect(controller.currentTheme).toBe("dr");
    });

    it("falls back to the system theme when the markup declares none", async () => {
      const { controller } = await mount(
        MARKUP.replace('data-theme-toggle-current-value="sy"', ""),
      );

      expect(controller.currentTheme).toBe("sy");
    });
  });
});
