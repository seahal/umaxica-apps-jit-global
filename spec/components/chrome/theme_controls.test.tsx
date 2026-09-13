import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import ThemeControls from "@/components/chrome/ThemeControls";
import { readString } from "@/lib/payload";
import type { ChromeThemeControls } from "@/types/inertia";

import { jsonBody, jsonResponse, stubFetchAnswering, stubFetchByMethod } from "../../support/http";

// The React port of the `theme` Stimulus controller is verified against the same behaviour: the
// stored preference read on mount, a choice persisted then applied from the server's answer, and
// the system setting followed while "system" is selected.
const controls: ChromeThemeControls = {
  hidden: false,
  title: "テーマ",
  description: "この端末の表示テーマを選びます。",
  options: { system: "システム", light: "ライト", dark: "ダーク" },
};

type MediaListener = () => void;

let container: HTMLDivElement | undefined;
let root: Root | undefined;
let mediaMatches: boolean;
let listeners: MediaListener[];
let removedListeners: MediaListener[];

const mount = async (overrides: Partial<ChromeThemeControls> = {}) => {
  container = document.createElement("div");
  document.body.append(container);
  const mounted = createRoot(container);
  root = mounted;
  await act(async () => {
    mounted.render(<ThemeControls controls={{ ...controls, ...overrides }} />);
  });
};

// React Aria's RadioGroup generates the shared `name` itself, so the radios are located by type
// and value rather than by a name this component no longer chooses.
const radio = (value: string) =>
  container?.querySelector<HTMLInputElement>(`input[type="radio"][value="${value}"]`);

const selectedTheme = () =>
  [...(container?.querySelectorAll<HTMLInputElement>('input[type="radio"]') ?? [])].find(
    (input) => input.checked,
  )?.value;

const choose = async (value: string) => {
  await act(async () => {
    radio(value)?.click();
  });
};

// The mount read and the write hit the same endpoint, so the responses are separated by method:
// a read that answers nothing keeps the control on the cookie theme until a choice is made.
const stubFetch = (patch: { theme?: string } | Error) => {
  const fetchMock = vi.fn().mockImplementation((_url: string, init?: RequestInit) => {
    if (init?.method !== "PATCH") {
      return Promise.resolve({ ok: false, status: 404 });
    }
    return patch instanceof Error
      ? Promise.reject(patch)
      : Promise.resolve({ ok: true, json: () => Promise.resolve(patch) });
  });
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
};

function clearCookies() {
  for (const part of document.cookie.split(";")) {
    const [key] = part.trim().split("=");
    if (key) {
      document.cookie = `${key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
    }
  }
}

beforeEach(() => {
  mediaMatches = false;
  listeners = [];
  removedListeners = [];
  clearCookies();
  document.documentElement.className = "";
  delete document.documentElement.dataset["theme"];
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-token">';
  window.history.replaceState({}, "", "/?ri=jp");

  vi.stubGlobal(
    "matchMedia",
    vi.fn((query: string) => ({
      media: query,
      get matches() {
        return mediaMatches;
      },
      addEventListener: (_event: string, listener: MediaListener) => listeners.push(listener),
      removeEventListener: (_event: string, listener: MediaListener) =>
        removedListeners.push(listener),
    })),
  );
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 404 }));
});

afterEach(() => {
  vi.unstubAllGlobals();
  const mounted = root;
  if (mounted) {
    act(() => {
      mounted.unmount();
    });
  }
  container?.remove();
  root = undefined;
  container = undefined;
  document.head.innerHTML = "";
  clearCookies();
});

describe("ThemeControls rendering", () => {
  test("renders one option per theme with the labels the server resolved", async () => {
    await mount();

    expect(container?.textContent).toContain(controls.title);
    expect(container?.textContent).toContain(controls.description);
    expect(container?.textContent).toContain("システム");
    expect(container?.textContent).toContain("ライト");
    expect(container?.textContent).toContain("ダーク");
  });

  // The surface decides whether the control belongs on the page at all.
  test("renders nothing when the surface hides the control", async () => {
    await mount({ hidden: true });

    expect(container?.textContent).toBe("");
  });

  // Rails renders `data-theme` from the `ct` cookie, so the attribute is what the first paint
  // already shows and what the control starts from; the cookie itself is read asynchronously now.
  test("starts from the theme the document was rendered with", async () => {
    document.documentElement.dataset["theme"] = "dark";

    await mount();

    expect(selectedTheme()).toBe("dark");
  });

  test("starts from system when the document carries no theme", async () => {
    await mount();

    expect(selectedTheme()).toBe("system");
  });

  // Rendered without a document there is no rendered theme to read, so the control starts from
  // system rather than reaching for one.
  test("starts from system when rendered without a document", () => {
    vi.stubGlobal("document", undefined);

    const html = renderToStaticMarkup(<ThemeControls controls={controls} />);

    expect(html).toContain('checked="" value="system"');
    expect(html).not.toContain('checked="" value="dark"');
  });
});

describe("ThemeControls mount", () => {
  test("adopts the stored preference the server answers with", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ theme: "li" }) }),
    );
    document.cookie = "ct=dr; path=/";

    await mount();

    expect(selectedTheme()).toBe("light");
    expect(document.documentElement.dataset["theme"]).toBe("light");
  });

  test("keeps the rendered theme when the stored preference cannot be read", async () => {
    document.documentElement.dataset["theme"] = "dark";

    await mount();

    expect(selectedTheme()).toBe("dark");
  });

  // The visitor is more current than an in-flight read, so a choice made first must win.
  test("does not overwrite a choice made before the stored preference arrives", async () => {
    // The PATCH answers at once; the GET is held open until this test decides it lands.
    const { settlePending } = stubFetchByMethod({ PATCH: jsonResponse({ theme: "dr" }) });

    await mount();
    await choose("dark");

    await act(async () => {
      settlePending(jsonResponse({ theme: "li" }));
    });

    expect(selectedTheme()).toBe("dark");
  });

  test("stops following the system setting once unmounted", async () => {
    await mount();

    const mounted = root;
    act(() => {
      mounted?.unmount();
    });

    expect(removedListeners).toEqual(listeners);
  });

  // The control sits in the persistent layout, so a visit never remounts it. The theme preference
  // screen writes the same cookie through the server, and the radio has to follow it.
  test("follows the cookie when the server changes it", async () => {
    await mount();
    expect(selectedTheme()).toBe("system");

    await act(async () => {
      await cookieStore.set({ name: "ct", value: "dr" });
    });

    expect(selectedTheme()).toBe("dark");
  });

  test("stops following the cookie once unmounted", async () => {
    await mount();

    const mounted = root;
    act(() => {
      mounted?.unmount();
    });
    await act(async () => {
      await cookieStore.set({ name: "ct", value: "dr" });
    });

    expect(container?.textContent).toBe("");
  });
});

describe("ThemeControls selection", () => {
  test("persists the choice and applies the theme the server stored", async () => {
    const fetchMock = stubFetch({ theme: "dr" });

    await mount();
    await choose("dark");

    expect(selectedTheme()).toBe("dark");
    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(fetchMock).toHaveBeenLastCalledWith("http://localhost:3000/web/v0/theme?ri=jp", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": "csrf-token",
      },
      body: JSON.stringify({ theme: "dark" }),
    });
  });

  // The stored preference is the authority, so the control follows the server rather than the
  // choice it optimistically applied.
  test("reconciles with the theme the server actually stored", async () => {
    stubFetch({ theme: "li" });

    await mount();
    await choose("dark");

    expect(selectedTheme()).toBe("light");
    expect(document.documentElement.dataset["theme"]).toBe("light");
  });

  test("leaves the rendered theme in place when the write fails", async () => {
    document.documentElement.dataset["theme"] = "dark";
    stubFetch(new Error("offline"));

    await mount();
    await choose("light");

    expect(selectedTheme()).toBe("dark");
    expect(document.documentElement.dataset["theme"]).toBe("dark");
  });

  test("does not apply a colour until the server accepts the write", async () => {
    document.documentElement.dataset["theme"] = "light";
    const { settlePending } = stubFetchByMethod({ GET: jsonResponse({ theme: "li" }) });

    await mount();
    expect(selectedTheme()).toBe("light");

    act(() => {
      radio("dark")?.click();
    });

    expect(document.documentElement.dataset["theme"]).toBe("light");
    expect(selectedTheme()).toBe("light");

    await act(async () => {
      settlePending(jsonResponse({ theme: "dr" }));
    });

    expect(selectedTheme()).toBe("dark");
    expect(document.documentElement.dataset["theme"]).toBe("dark");
  });

  test("follows the system setting while system is the selected theme", async () => {
    const storedCode: Record<string, string> = { dark: "dr", system: "sy" };
    stubFetchAnswering({
      GET: () => jsonResponse({}, 404),
      PATCH: (init) =>
        jsonResponse({ theme: storedCode[String(readString(jsonBody(init), "theme"))] }),
    });

    await mount();
    await choose("dark");
    expect(selectedTheme()).toBe("dark");
    await choose("system");
    expect(selectedTheme()).toBe("system");
    expect(document.documentElement.classList.contains("dark")).toBe(false);

    mediaMatches = true;
    await act(async () => {
      for (const listener of listeners) {
        listener();
      }
    });

    expect(document.documentElement.classList.contains("dark")).toBe(true);
    expect(selectedTheme()).toBe("system");
  });

  test("stops following the system setting after an explicit choice", async () => {
    stubFetch({ theme: "li" });

    await mount();
    await choose("light");

    mediaMatches = true;
    await act(async () => {
      for (const listener of listeners) {
        listener();
      }
    });

    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });
});
