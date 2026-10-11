// The theme radio group on the surfaces that do not boot React.
//
// The mapping, the cookie parsing, the DOM application and both HTTP calls live in `@/lib/theme`
// and are covered by spec/lib/theme.test.ts. What belongs here is what the controller itself
// decides: which radio is checked, that a colour change waits for the server to accept the write,
// that the visitor's own choice outranks a slower stored-preference read, and that an unreachable
// server falls back to the cookie the first paint already used.
import { Controller } from "@hotwired/stimulus";
import { beforeEach, describe, expect, it, vi } from "vitest";

import ThemeController from "@/controllers/theme_controller";

import {
  type FetchMock,
  jsonResponse as httpJson,
  requestWithMethod,
  stubFetchAnswering,
} from "../support/http";
import { mountController } from "../support/stimulus";

const jsonResponse = (body: unknown, ok = true) => httpJson(body, ok ? 200 : 500);

/** A response the spec settles by hand, for asserting on what happens while it is still open. */
function deferredResponse(): { promise: Promise<Response>; resolve: (value: Response) => void } {
  const settlers: ((value: Response) => void)[] = [];
  const promise = new Promise<Response>((settle) => {
    settlers.push(settle);
  });

  return { promise, resolve: (value) => settlers.forEach((settle) => settle(value)) };
}

/** The PATCH the controller sends when a theme is chosen; `connect` issues a GET before it. */
const patchedTheme = (fetchMock: FetchMock): unknown => requestWithMethod(fetchMock, "PATCH")?.body;

const RADIO_GROUP = `
  <aside data-controller="theme">
    <form>
      <input type="radio" name="theme" value="system">
      <input type="radio" name="theme" value="light">
      <input type="radio" name="theme" value="dark">
    </form>
  </aside>
  <span id="js-theme-cookie-value"></span>
`;

const mountRadioGroup = () =>
  mountController<ThemeController>("theme", ThemeController, RADIO_GROUP);

function checkedTheme(element: HTMLElement): string | null {
  const checked = [...element.querySelectorAll<HTMLInputElement>("input")].find(
    (input) => input.checked,
  );
  return checked?.value ?? null;
}

function readout(): string | null {
  return document.querySelector("#js-theme-cookie-value")?.textContent ?? null;
}

function selectEvent(value: string): Event {
  const input = document.querySelector<HTMLInputElement>(`input[value="${value}"]`)!;
  const event = new Event("change");
  Object.defineProperty(event, "target", { value: input });
  return event;
}

beforeEach(() => {
  document.cookie = "ct=";
  document.documentElement.className = "";
  delete document.documentElement.dataset["theme"];
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  vi.restoreAllMocks();
});

describe("ThemeController", () => {
  it("is a Stimulus controller, so the registry can register it", () => {
    expect(ThemeController.prototype).toBeInstanceOf(Controller);
  });

  describe("connect", () => {
    it("checks the radio for the theme the server has stored", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>(() => Promise.resolve(jsonResponse({ theme: "dr" }))),
      );
      const { controller, element } = await mountRadioGroup();

      await controller.syncFromServer();

      expect(checkedTheme(element)).toBe("dark");
      expect(document.documentElement.dataset["theme"]).toBe("dark");
      expect(readout()).toBe("dark");
    });

    it("falls back to the cookie when the server cannot be reached", async () => {
      document.cookie = "ct=li";
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>(() => Promise.reject(new Error("offline"))),
      );
      const { controller, element } = await mountRadioGroup();

      await controller.syncFromServer();

      expect(checkedTheme(element)).toBe("light");
      expect(document.documentElement.dataset["theme"]).toBe("light");
    });

    it("falls back to the cookie when the server answers an error status", async () => {
      document.cookie = "ct=dr";
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>(() => Promise.resolve(jsonResponse({}, false))),
      );
      const { controller, element } = await mountRadioGroup();

      await controller.syncFromServer();

      expect(checkedTheme(element)).toBe("dark");
    });

    it("leaves a choice the visitor already made in place", async () => {
      // The stored answer is held open so the visitor's own choice can land first, which is the
      // ordering this guard exists for.
      const stored = deferredResponse();
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>(() => stored.promise),
      );
      const { controller, element } = await mountRadioGroup();

      const syncing = controller.syncFromServer();
      controller.showTheme("light");
      // The visitor picks before the slower stored answer lands.
      Object.assign(controller, { selectedTheme: "light" });
      stored.resolve(jsonResponse({ theme: "dr" }));
      await syncing;

      expect(checkedTheme(element)).toBe("light");
    });
  });

  describe("select", () => {
    it("reports the choice and applies the theme the server stored", async () => {
      const fetchMock = vi.fn<typeof fetch>(() => Promise.resolve(jsonResponse({ theme: "dr" })));
      vi.stubGlobal("fetch", fetchMock);
      const { controller, element } = await mountRadioGroup();

      controller.select(selectEvent("dark"));
      await controller.persist("dark");

      expect(document.documentElement.dataset["theme"]).toBe("dark");
      expect(checkedTheme(element)).toBe("dark");
      expect(patchedTheme(fetchMock)).toEqual({ theme: "dark" });
    });

    it("shows what the server stored when it differs from the request", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>(() => Promise.resolve(jsonResponse({ theme: "li" }))),
      );
      const { controller, element } = await mountRadioGroup();

      await controller.persist("dark");

      expect(checkedTheme(element)).toBe("light");
    });

    it("leaves the rendered theme in place when the server answers no theme", async () => {
      stubFetchAnswering({
        GET: () => jsonResponse({ theme: "li" }),
        PATCH: () => jsonResponse({}),
      });
      const { controller, element } = await mountRadioGroup();
      await controller.syncFromServer();

      await controller.persist("dark");

      expect(checkedTheme(element)).toBe("light");
      expect(document.documentElement.dataset["theme"]).toBe("light");
    });

    it("leaves the rendered theme in place when the request fails", async () => {
      stubFetchAnswering({
        GET: () => jsonResponse({ theme: "dr" }),
        PATCH: () => Promise.reject(new Error("offline")),
      });
      const { controller, element } = await mountRadioGroup();
      await controller.syncFromServer();

      await controller.persist("light");

      expect(checkedTheme(element)).toBe("dark");
      expect(document.documentElement.dataset["theme"]).toBe("dark");
    });

    it("ignores a change event that did not come from a radio", async () => {
      const fetchMock = vi.fn<typeof fetch>(() => Promise.resolve(jsonResponse({})));
      vi.stubGlobal("fetch", fetchMock);
      const { controller } = await mountRadioGroup();

      const event = new Event("change");
      Object.defineProperty(event, "target", { value: document.createElement("span") });
      controller.select(event);

      // `connect` already issued the GET that reads the stored theme; nothing was reported.
      expect(patchedTheme(fetchMock)).toBeUndefined();
    });

    it("treats a value it does not recognise as the system theme", async () => {
      vi.stubGlobal(
        "fetch",
        vi.fn<typeof fetch>(() => Promise.resolve(jsonResponse({ theme: "sy" }))),
      );
      const { controller, element } = await mountRadioGroup();

      const stray = document.createElement("input");
      stray.type = "radio";
      stray.value = "chartreuse";
      const event = new Event("change");
      Object.defineProperty(event, "target", { value: stray });
      controller.select(event);
      await controller.persist("system");

      expect(checkedTheme(element)).toBe("system");
    });
  });

  describe("showTheme", () => {
    it("does not fail when the page carries no readout element", async () => {
      const { controller } = await mountRadioGroup();
      document.querySelector("#js-theme-cookie-value")?.remove();

      expect(() => controller.showTheme("dark")).not.toThrow();
    });

    it("does not fail when the group carries no radio for the theme", async () => {
      const { controller } = await mountRadioGroup();
      document.querySelectorAll("input").forEach((input) => input.remove());

      expect(() => controller.showTheme("dark")).not.toThrow();
      expect(document.documentElement.dataset["theme"]).toBe("dark");
    });
  });
});
