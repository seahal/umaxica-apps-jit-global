import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  applyTheme,
  codeFromTheme,
  fetchStoredTheme,
  persistTheme,
  readThemeCookie,
  themeFromCode,
  themeFromDocument,
  watchThemeCookie,
  watchSystemTheme,
} from "@/lib/theme";

import { present } from "../support/present";

type MediaListener = () => void;

const COM_EXPERIENCE = {
  theme: "dark",
  timezone: "Asia/Tokyo",
  currency: "jpy",
  date_format: "iso",
  time_format: "24",
  motion: "standard",
  density: "standard",
  page_size: "infinity",
};

let mediaMatches: boolean;
let listeners: MediaListener[];
let removed: MediaListener[];

function stubMatchMedia() {
  mediaMatches = false;
  listeners = [];
  removed = [];

  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      media: query,
      get matches() {
        return mediaMatches;
      },
      addEventListener: (_event: string, listener: MediaListener) => listeners.push(listener),
      removeEventListener: (_event: string, listener: MediaListener) => removed.push(listener),
    })),
  );
}

function clearCookies() {
  for (const part of document.cookie.split(";")) {
    const [key] = part.trim().split("=");
    if (key) {
      document.cookie = `${key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
    }
  }
}

beforeEach(() => {
  stubMatchMedia();
  clearCookies();
  document.documentElement.className = "";
  delete document.documentElement.dataset["theme"];
  delete document.documentElement.dataset["edition"];
  window.history.replaceState({}, "", "/");
});

afterEach(() => {
  vi.unstubAllGlobals();
  clearCookies();
});

describe("themeFromCode", () => {
  test.each([
    ["dr", "dark"],
    ["dark", "dark"],
    ["li", "light"],
    ["light", "light"],
    ["sy", "system"],
    ["system", "system"],
    ["DR", "dark"],
  ])("maps the stored code %s to %s", (code, theme) => {
    expect(themeFromCode(code)).toBe(theme);
  });

  test.each([[null], [undefined], [""], ["nonsense"]])(
    "falls back to system for %s",
    (value: string | null | undefined) => {
      expect(themeFromCode(value)).toBe("system");
    },
  );
});

describe("codeFromTheme", () => {
  test.each([
    ["dark", "dr"],
    ["light", "li"],
    ["system", "sy"],
  ] as const)("maps %s to the wire code %s", (theme, code) => {
    expect(codeFromTheme(theme)).toBe(code);
  });
});

describe("readThemeCookie", () => {
  test("com reads the experience theme instead of the retired ct cookie", async () => {
    document.documentElement.dataset["edition"] = "com";
    document.cookie = "ct=li; path=/";
    document.cookie = `__Secure-experience=${encodeURIComponent(JSON.stringify(COM_EXPERIENCE))}; Secure; Path=/`;

    await expect(readThemeCookie()).resolves.toBe("dark");
  });

  test("com retains the server-rendered theme when experience is absent or malformed", async () => {
    document.documentElement.dataset["edition"] = "com";
    document.documentElement.dataset["theme"] = "dark";
    document.cookie = "ct=li; path=/";

    await expect(readThemeCookie()).resolves.toBe("dark");
    document.cookie = "__Secure-experience=invalid; Secure; Path=/";
    await expect(readThemeCookie()).resolves.toBe("dark");
  });

  test("com does not trust either of two same-name experience cookies", async () => {
    document.documentElement.dataset["edition"] = "com";
    document.documentElement.dataset["theme"] = "dark";
    window.history.replaceState({}, "", "/nested/page");
    document.cookie = `__Secure-experience=${encodeURIComponent(JSON.stringify(COM_EXPERIENCE))}; Secure; Path=/`;
    document.cookie = `__Secure-experience=${encodeURIComponent(JSON.stringify({ ...COM_EXPERIENCE, theme: "light" }))}; Secure; Path=/nested`;

    try {
      await expect(readThemeCookie()).resolves.toBe("dark");
    } finally {
      document.cookie = "__Secure-experience=; Secure; Path=/nested; Max-Age=0";
    }
  });

  test.each([
    JSON.stringify({ theme: "light" }),
    JSON.stringify({ ...COM_EXPERIENCE, theme: "light", timezone: "unknown" }),
    JSON.stringify({ ...COM_EXPERIENCE, theme: "light", unexpected: "value" }),
    JSON.stringify({ ...COM_EXPERIENCE, theme: "light" }).replace(
      '"theme":"light"',
      '"theme":"dark","theme":"light"',
    ),
  ])("com preserves the rendered theme for an invalid experience projection", async (value) => {
    document.documentElement.dataset["edition"] = "com";
    document.documentElement.dataset["theme"] = "dark";
    document.cookie = `__Secure-experience=${encodeURIComponent(value)}; Secure; Path=/`;

    await expect(readThemeCookie()).resolves.toBe("dark");
  });

  test("com preserves a request theme overlay when an experience cookie is present", async () => {
    document.documentElement.dataset["edition"] = "com";
    document.documentElement.dataset["theme"] = "light";
    window.history.replaceState({}, "", "/?ct=li");
    document.cookie = `__Secure-experience=${encodeURIComponent(JSON.stringify(COM_EXPERIENCE))}; Secure; Path=/`;

    await expect(readThemeCookie()).resolves.toBe("light");
  });

  test("com watches the experience cookie rather than the retired ct cookie", async () => {
    document.documentElement.dataset["edition"] = "com";
    document.cookie = `__Secure-experience=${encodeURIComponent(JSON.stringify(COM_EXPERIENCE))}; Secure; Path=/`;
    const seen: string[] = [];
    const stop = watchThemeCookie((theme) => seen.push(theme));
    const event = new Event("change");
    Object.defineProperties(event, {
      changed: {
        value: [
          {
            name: "__Secure-experience",
            value: encodeURIComponent(JSON.stringify(COM_EXPERIENCE)),
          },
        ],
      },
      deleted: { value: [] },
    });
    window.cookieStore.dispatchEvent(event);
    await vi.waitFor(() => expect(seen).toEqual(["dark"]));
    stop();
  });

  test("com rechecks same-name cookie ambiguity after a cookie change", async () => {
    document.documentElement.dataset["edition"] = "com";
    document.documentElement.dataset["theme"] = "dark";
    window.history.replaceState({}, "", "/nested/page");
    const light = JSON.stringify({ ...COM_EXPERIENCE, theme: "light" });
    document.cookie = `__Secure-experience=${encodeURIComponent(JSON.stringify(COM_EXPERIENCE))}; Secure; Path=/`;
    document.cookie = `__Secure-experience=${encodeURIComponent(light)}; Secure; Path=/nested`;
    const seen: string[] = [];
    const stop = watchThemeCookie((theme) => seen.push(theme));
    const event = new Event("change");
    Object.defineProperties(event, {
      changed: { value: [{ name: "__Secure-experience", value: encodeURIComponent(light) }] },
      deleted: { value: [] },
    });

    try {
      window.cookieStore.dispatchEvent(event);
      await vi.waitFor(() => expect(seen).toEqual(["dark"]));
    } finally {
      stop();
      document.cookie = "__Secure-experience=; Secure; Path=/nested; Max-Age=0";
    }
  });

  test("reads the theme Rails rendered the first paint from", async () => {
    document.cookie = "ct=dr; path=/";

    await expect(readThemeCookie()).resolves.toBe("dark");
  });

  test("reads ct even when other cookies are present", async () => {
    document.cookie = "lx=en; path=/";
    document.cookie = "ct=li; path=/";
    document.cookie = "tz=asia%2Ftokyo; path=/";

    await expect(readThemeCookie()).resolves.toBe("light");
  });

  test("decodes a percent encoded value", async () => {
    document.cookie = `ct=${encodeURIComponent("system")}; path=/`;

    await expect(readThemeCookie()).resolves.toBe("system");
  });

  test("falls back to system without a ct cookie", async () => {
    document.cookie = "lx=en; path=/";

    await expect(readThemeCookie()).resolves.toBe("system");
  });

  test("falls back to system when ct carries no value", async () => {
    document.cookie = "ct=; path=/";

    await expect(readThemeCookie()).resolves.toBe("system");
  });
});

describe("themeFromDocument", () => {
  test("reads the theme Rails rendered onto the document", () => {
    document.documentElement.dataset["theme"] = "dark";

    expect(themeFromDocument()).toBe("dark");
  });

  test("reads the theme a previous application wrote", () => {
    applyTheme("light");

    expect(themeFromDocument()).toBe("light");
  });

  test("falls back to system when the document carries no theme", () => {
    delete document.documentElement.dataset["theme"];

    expect(themeFromDocument()).toBe("system");
  });

  test("falls back to system for a value the stylesheets do not answer to", () => {
    document.documentElement.dataset["theme"] = "nonsense";

    expect(themeFromDocument()).toBe("system");
  });
});

describe("applyTheme", () => {
  test("marks the document dark for an explicit dark choice", () => {
    applyTheme("dark");

    expect(document.documentElement.dataset["theme"]).toBe("dark");
    expect(document.documentElement.classList.contains("theme-dark")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  test("marks the document light for an explicit light choice", () => {
    applyTheme("light");

    expect(document.documentElement.dataset["theme"]).toBe("light");
    expect(document.documentElement.classList.contains("theme-light")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  test("resolves the system choice against the system setting", () => {
    mediaMatches = true;
    applyTheme("system");

    expect(document.documentElement.dataset["theme"]).toBe("system");
    expect(document.documentElement.classList.contains("theme-system")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);

    mediaMatches = false;
    applyTheme("system");

    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  test("replaces the class of the previously applied theme", () => {
    applyTheme("dark");
    applyTheme("light");

    expect(document.documentElement.classList.contains("theme-dark")).toBe(false);
    expect(document.documentElement.classList.contains("theme-light")).toBe(true);
  });
});

describe("watchSystemTheme", () => {
  test("reapplies the caller's current theme when the system setting changes", () => {
    let current: "dark" | "light" | "system" = "system";
    const stop = watchSystemTheme(() => current);

    mediaMatches = true;
    for (const listener of listeners) {
      listener();
    }
    expect(document.documentElement.classList.contains("dark")).toBe(true);

    // An explicit choice must survive a system change.
    current = "light";
    for (const listener of listeners) {
      listener();
    }
    expect(document.documentElement.classList.contains("dark")).toBe(false);

    stop();
    expect(removed).toEqual(listeners);
  });
});

// The server declares the endpoint for each page; the helpers only resolve it on the current origin.
const THEME_ENDPOINT = "/api/v0/preferences/theme";

describe("fetchStoredTheme", () => {
  test("refuses an endpoint on another origin before any request", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      fetchStoredTheme("https://base.example.test/api/v0/preferences/theme"),
    ).rejects.toThrow(/same-origin/u);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("reads the stored preference through the theme endpoint", async () => {
    window.history.replaceState({}, "", "/?ct=dr&ri=jp");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ theme: "dr" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(fetchStoredTheme(THEME_ENDPOINT)).resolves.toBe("dark");
    expect(fetchMock).toHaveBeenCalledWith(
      "http://localhost:3000/api/v0/preferences/theme?ct=dr&ri=jp",
    );
  });

  test("falls back to system when the endpoint answers an unknown code", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }),
    );

    await expect(fetchStoredTheme(THEME_ENDPOINT)).resolves.toBe("system");
  });

  test("returns null on an error response so the cookie stays authoritative", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await expect(fetchStoredTheme(THEME_ENDPOINT)).resolves.toBeNull();
  });

  test("returns null when the request itself fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));

    await expect(fetchStoredTheme(THEME_ENDPOINT)).resolves.toBeNull();
  });
});

describe("persistTheme", () => {
  test("refuses a protocol-relative endpoint naming another host before any request", async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(
      persistTheme("//base.example.test/api/v0/preferences/theme", "dark", "csrf"),
    ).rejects.toThrow(/same-origin/u);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("sends the choice with the CSRF token and returns what the server stored", async () => {
    // The theme being replaced must not be echoed back to the endpoint as a request parameter.
    window.history.replaceState({}, "", "/?ct=li&theme=light&ri=jp");
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ theme: "dr" }),
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(persistTheme(THEME_ENDPOINT, "dark", "csrf-token")).resolves.toBe("dark");
    expect(fetchMock).toHaveBeenCalledWith("http://localhost:3000/api/v0/preferences/theme?ri=jp", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": "csrf-token",
      },
      body: JSON.stringify({ theme: "dark" }),
    });
  });

  test("omits the CSRF header when no token is available", async () => {
    const fetchMock = vi.fn<typeof fetch>(() =>
      Promise.resolve(new Response(JSON.stringify({ theme: "li" }))),
    );
    vi.stubGlobal("fetch", fetchMock);

    await expect(persistTheme(THEME_ENDPOINT, "light", "")).resolves.toBe("light");
    const [, init] = present(fetchMock.mock.calls[0], "the first fetch call");
    expect(present(init, "the request options").headers).not.toHaveProperty("X-CSRF-Token");
  });

  test("returns null when the response carries no theme", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }),
    );

    await expect(persistTheme(THEME_ENDPOINT, "dark", "csrf-token")).resolves.toBeNull();
  });

  test("returns null when the endpoint rejects the write", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 422 }));

    await expect(persistTheme(THEME_ENDPOINT, "system", "csrf-token")).resolves.toBeNull();
  });

  test("returns null when the request itself fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));

    await expect(persistTheme(THEME_ENDPOINT, "light", "csrf-token")).resolves.toBeNull();
  });
});
