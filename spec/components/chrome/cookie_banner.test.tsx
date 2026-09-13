import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import CookieBanner from "@/components/chrome/CookieBanner";
import type { ChromeCookieControls } from "@/types/inertia";

import { jsonResponse, noContentResponse, stubFetchByMethod } from "../../support/http";

// The React port of the `cookie-banner` Stimulus controller is verified against the same
// behaviour the controller spec asserts: the consent read on mount, the PATCH payload of each
// answer, the close button and the settings navigation.
const controls: ChromeCookieControls = {
  hidden: false,
  scope: "cookie",
  settings_url: "/preference/cookie/edit?ri=jp",
  title: "Cookie の利用について",
  description_html: "この端末の Cookie 設定を選べます。",
  close_button: "閉じる",
  reject_all: "すべて拒否",
  open_settings: "設定を開く",
  accept_all: "すべて許可",
};

const ENDPOINT = "http://localhost:3000/web/v0/cookie?ri=us&lx=en&ct=dr&tz=asia%2Ftokyo";

let container: HTMLDivElement | undefined;
let root: Root | undefined;
let assign: ReturnType<typeof vi.fn>;
let fetchMock: ReturnType<typeof vi.fn>;

const stubFetch = (mock: ReturnType<typeof vi.fn>) => {
  fetchMock = mock;
  vi.stubGlobal("fetch", mock);
};

const noop = () => {};

const mount = async (overrides: Partial<ChromeCookieControls> = {}) => {
  container = document.createElement("div");
  document.body.append(container);
  const mounted = createRoot(container);
  root = mounted;
  await act(async () => {
    mounted.render(<CookieBanner controls={{ ...controls, ...overrides }} />);
  });
};

const banner = () => container?.querySelector("#cookie-banner");

// The JS-readable projection of the recorded decision, written by
// `PreferenceConsentedBuffer#set_preference_consented_buffer!`.
const consentBufferCookie = (value: string) => {
  document.cookie = `preference_consented=${value}; path=/`;
};

const clearCookies = () => {
  for (const part of document.cookie.split(";")) {
    const [key] = part.trim().split("=");
    if (key) {
      document.cookie = `${key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
    }
  }
};
const button = (label: string) =>
  [...(container?.querySelectorAll("button") ?? [])].find(
    (element) => element.textContent === label || element.getAttribute("aria-label") === label,
  );

const click = async (element: HTMLButtonElement | undefined) => {
  await act(async () => {
    element?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

beforeEach(() => {
  clearCookies();
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-token">';
  assign = vi.fn();
  // jsdom's location is not redefinable in place, so the whole object is stubbed; the query string
  // carries the preference context the endpoint URL is built from.
  vi.stubGlobal("location", {
    origin: "http://localhost:3000",
    search: "?ct=dr&lx=en&ri=us&rt=ignored&tz=asia%2Ftokyo",
    assign,
  });
  stubFetch(vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }));
});

afterEach(() => {
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
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("CookieBanner mount", () => {
  test("renders nothing when the cookie screen already owns consent", async () => {
    stubFetch(vi.fn());

    await mount({ hidden: true });

    expect(banner()).toBeNull();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  // `show_banner` is the field `PreferenceWebCookieActions#show` answers with. The banner used to
  // read `consented`, which that response has never carried, so a recorded decision never
  // suppressed it and the prompt returned on every load.
  test("hides the banner when the API reports an existing consent", async () => {
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ show_banner: false }) }),
    );

    await mount();

    expect(fetchMock).toHaveBeenCalledWith(ENDPOINT);
    expect(banner()).toBeNull();
  });

  test("keeps the banner when no consent is recorded yet", async () => {
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ show_banner: true }) }),
    );

    await mount();

    expect(banner()).not.toBeNull();
    expect(banner()?.textContent).toContain(controls.title);
    expect(banner()?.textContent).toContain(controls.description_html);
  });

  test("keeps the banner when the answer names no decision at all", async () => {
    stubFetch(vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({}) }));

    await mount();

    expect(banner()).not.toBeNull();
  });

  // Without this the banner paints on every load and disappears once the read returns, which is
  // the flash the consent buffer cookie exists to prevent.
  test("never paints for a visitor whose consent buffer cookie records an answer", async () => {
    consentBufferCookie("1");
    let resolveRead: (value: unknown) => void = noop;
    stubFetch(
      vi.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveRead = resolve;
        }),
      ),
    );

    await mount();

    expect(banner()).toBeNull();

    await act(async () => {
      resolveRead({ ok: true, json: () => Promise.resolve({ show_banner: false }) });
    });

    expect(banner()).toBeNull();
  });

  // The buffer is a projection; the endpoint is the authority, so it raises the banner again when
  // the two disagree.
  test("raises the banner when the endpoint contradicts a stale consent buffer cookie", async () => {
    consentBufferCookie("1");
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ show_banner: true }) }),
    );

    await mount();

    expect(banner()).not.toBeNull();
  });

  // The buffer read is asynchronous through the Cookie Store API, so it is the only thing that can
  // raise the banner before the endpoint answers.
  test("raises the banner from the buffer cookie while the endpoint is still pending", async () => {
    let resolveRead: (value: unknown) => void = noop;
    stubFetch(
      vi.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveRead = resolve;
        }),
      ),
    );

    await mount();

    expect(banner()).not.toBeNull();

    await act(async () => {
      resolveRead({ ok: true, json: () => Promise.resolve({ show_banner: true }) });
    });

    expect(banner()).not.toBeNull();
  });

  // The endpoint is the authority, so a buffer read that lands after it must not undo its answer.
  test("keeps the banner hidden when the buffer read lands after the endpoint hid it", async () => {
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ show_banner: false }) }),
    );
    // The component only reads, so the store is stood in for by a slow read of the real one.
    const store = window.cookieStore;
    vi.stubGlobal("cookieStore", {
      get: (name: string) =>
        new Promise((resolve) => {
          setTimeout(() => void store.get(name).then(resolve), 0);
        }),
    });

    await mount();
    await act(async () => {
      await vi.waitFor(() => expect(banner()).toBeNull());
    });

    expect(banner()).toBeNull();
  });

  test("paints immediately when the consent buffer cookie records no answer", async () => {
    consentBufferCookie("0");
    stubFetch(
      vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ show_banner: true }) }),
    );

    await mount();

    expect(banner()).not.toBeNull();
  });

  test("keeps the banner when the consent read answers an error", async () => {
    stubFetch(vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await mount();

    expect(banner()).not.toBeNull();
  });

  test("keeps the banner when the consent read fails", async () => {
    stubFetch(vi.fn().mockRejectedValue(new Error("offline")));

    await mount();

    expect(banner()).not.toBeNull();
  });

  // The read is aborted on unmount so a late answer cannot update a component that is gone.
  test("ignores a consent answer that arrives after unmount", async () => {
    let resolveRead: (value: unknown) => void = noop;
    stubFetch(
      vi.fn().mockReturnValue(
        new Promise((resolve) => {
          resolveRead = resolve;
        }),
      ),
    );

    await mount();
    const mounted = root;
    act(() => {
      mounted?.unmount();
    });

    await act(async () => {
      resolveRead({ ok: true, json: () => Promise.resolve({ show_banner: false }) });
    });

    // Re-mounted in afterEach terms: unmounting twice is safe, and no state update was attempted.
    expect(container?.textContent).toBe("");
  });
});

describe("CookieBanner actions", () => {
  const patchPayload = (consented: boolean) => [
    ENDPOINT,
    {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": "csrf-token",
      },
      body: JSON.stringify({
        cookie: {
          consented: true,
          functional: consented,
          performant: consented,
          targetable: consented,
        },
      }),
    },
  ];

  test("accepting sends consent for every category and hides the banner", async () => {
    await mount();
    await click(button(controls.accept_all));

    expect(fetchMock).toHaveBeenLastCalledWith(...patchPayload(true));
    expect(banner()).toBeNull();
  });

  test("rejecting still records the decision but refuses every category", async () => {
    await mount();
    await click(button(controls.reject_all));

    expect(fetchMock).toHaveBeenLastCalledWith(...patchPayload(false));
    expect(banner()).toBeNull();
  });

  test("keeps the banner when the server rejects the decision", async () => {
    await mount();
    stubFetch(vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await click(button(controls.reject_all));

    expect(banner()).not.toBeNull();
    expect(button(controls.reject_all)?.disabled).toBe(false);
  });

  test("the close button dismisses the banner without recording a decision", async () => {
    await mount();
    const calls = fetchMock.mock.calls.length;

    await click(button(controls.close_button));

    expect(banner()).toBeNull();
    expect(fetchMock.mock.calls.length).toBe(calls);
  });

  // The read is in flight while the visitor answers, so its answer is already stale when it lands.
  test("does not raise the banner again when a slow read lands after a decision", async () => {
    // The write is answered as the server answers it, 204 with no body; the read is left pending
    // until after the decision.
    const { settlePending } = stubFetchByMethod({ PATCH: noContentResponse() });

    await mount();
    await click(button(controls.accept_all));

    expect(banner()).toBeNull();

    await act(async () => {
      settlePending(jsonResponse({ show_banner: true }));
    });

    expect(banner()).toBeNull();
  });

  test("the settings control is a document visit to the cookie preference screen", async () => {
    await mount();

    const link = [...container!.querySelectorAll("a")].find(
      (element) => element.textContent === controls.open_settings,
    );

    // A button that called location.assign never reached the preference screen: the press
    // handler did not navigate, and there was no href to follow without script. The destination
    // has to be in the markup as a document visit — cookie preferences live on the base host,
    // which an Inertia XHR would not be allowed to load.
    expect(link?.getAttribute("href")).toBe(controls.settings_url);
    expect(link?.dataset["inertia"]).toBeUndefined();
    expect(assign).not.toHaveBeenCalled();
  });
});
