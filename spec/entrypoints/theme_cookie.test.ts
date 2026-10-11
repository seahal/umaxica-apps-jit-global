// The early-boot theme script, exercised against the real document rather than a stand-in for it.
//
// The mapping, the cookie parsing and the class application all live in `@/lib/theme` and are
// covered there; what belongs here is what this module adds: reading the cookie on boot, keeping
// the readout element in step, and following the system setting while the choice is "system".
import { beforeEach, describe, expect, it, vi } from "vitest";

type MediaListener = () => void;

const systemPrefersDark = { matches: false };
const mediaListeners = new Set<MediaListener>();

function installMatchMedia() {
  // Prefer replacing `window.matchMedia` over `vi.stubGlobal`: spec/setup.ts already defines
  // that own-property, and a global stub does not replace it in jsdom.
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    writable: true,
    value: vi.fn(() => ({
      get matches() {
        return systemPrefersDark.matches;
      },
      addEventListener: (_event: string, listener: MediaListener) => mediaListeners.add(listener),
      removeEventListener: (_event: string, listener: MediaListener) =>
        mediaListeners.delete(listener),
    })),
  });
}

installMatchMedia();

const { applyThemeFromCookie } = await import("@/theme_cookie");

function setThemeCookie(code: string) {
  document.cookie = `ct=${code}`;
}

beforeEach(() => {
  // Do not replace `window.matchMedia` after the first `applyThemeFromCookie`: the module
  // registers its system-theme watcher once and keeps that MediaQueryList for the suite.
  setThemeCookie("");
  systemPrefersDark.matches = false;
  document.documentElement.className = "";
  delete document.documentElement.dataset["theme"];
  document.body.innerHTML = "";
});

describe("applyThemeFromCookie", () => {
  it("applies the dark theme for ct=dr", async () => {
    setThemeCookie("dr");
    await applyThemeFromCookie();

    expect(document.documentElement.dataset["theme"]).toBe("dark");
    expect(document.documentElement.classList.contains("theme-dark")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("applies the light theme for ct=li", async () => {
    setThemeCookie("li");
    await applyThemeFromCookie();

    expect(document.documentElement.dataset["theme"]).toBe("light");
    expect(document.documentElement.classList.contains("theme-light")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  it("follows the system setting for ct=sy", async () => {
    setThemeCookie("sy");
    systemPrefersDark.matches = true;
    await applyThemeFromCookie();

    expect(document.documentElement.dataset["theme"]).toBe("system");
    expect(document.documentElement.classList.contains("theme-system")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("falls back to the system theme when there is no cookie", async () => {
    await applyThemeFromCookie();

    expect(document.documentElement.dataset["theme"]).toBe("system");
  });

  it("falls back to the system theme for a code it does not know", async () => {
    // An unrecognised code is a server or storage fault. Applying it verbatim would put an
    // arbitrary string into `data-theme`, which the stylesheets do not answer to.
    setThemeCookie("unknown");
    await applyThemeFromCookie();

    expect(document.documentElement.dataset["theme"]).toBe("system");
  });

  it("publishes the applied theme into the readout element when the page carries one", async () => {
    setThemeCookie("li");
    document.body.innerHTML = '<span id="js-theme-cookie-value"></span>';

    await applyThemeFromCookie();

    expect(document.querySelector("#js-theme-cookie-value")?.textContent).toBe("light");
  });

  it("does not fail when the page carries no readout element", async () => {
    setThemeCookie("li");

    await expect(applyThemeFromCookie()).resolves.toBeUndefined();
  });

  // The module is a script the document loads, so it has to answer for both states it can find the
  // document in: still parsing, and already parsed.
  it("applies the theme when a document that is still parsing finishes loading", async () => {
    setThemeCookie("dr");
    // jsdom reports a parsed document, which is the other branch; this one owns the state a real
    // document is in while its scripts run.
    Object.defineProperty(document, "readyState", { value: "loading", configurable: true });
    vi.resetModules();
    await import("@/theme_cookie");

    expect(document.documentElement.dataset["theme"]).not.toBe("dark");

    document.dispatchEvent(new Event("DOMContentLoaded"));
    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("dark"));

    Reflect.deleteProperty(document, "readyState");
  });

  it("applies the theme as soon as it loads into an already parsed document", async () => {
    setThemeCookie("li");
    vi.resetModules();

    await import("@/theme_cookie");

    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("light"));
  });

  // A navigation is not what changes the theme; the cookie is. The preference screen saves through
  // the server, so the response's Set-Cookie is the signal, whether or not a page follows it.
  it("applies the theme again when the cookie changes", async () => {
    setThemeCookie("dr");
    await applyThemeFromCookie();

    await cookieStore.set({ name: "ct", value: "li" });

    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("light"));
  });

  it("falls back to the system theme when the cookie is deleted", async () => {
    setThemeCookie("dr");
    await applyThemeFromCookie();

    await cookieStore.delete("ct");

    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("system"));
  });

  it("re-applies the theme when the system setting changes", async () => {
    setThemeCookie("sy");
    await applyThemeFromCookie();
    expect(document.documentElement.classList.contains("dark")).toBe(false);

    systemPrefersDark.matches = true;
    mediaListeners.forEach((listener) => listener());

    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });
});
