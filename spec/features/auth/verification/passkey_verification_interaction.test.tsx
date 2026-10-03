import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// Mount the real step-up screen and exercise its same-origin options and assertion requests.
import type { getAssertion as realGetAssertion } from "@/features/auth/passkeys/webauthn";

const STEP_UP_CANCEL = {
  label: "キャンセル",
  action: "/verification/cancellation?ri=jp",
  method: "post" as const,
};

// Typed from the real exports, so a mocked answer that does not match what the module promises is
// a failure here rather than an `any` flowing into the component under test.
const getAssertion = vi.fn<typeof realGetAssertion>();
const passkeysSupported = vi.fn<() => boolean>();
const solveInvisibleTurnstile = vi.fn<() => Promise<string>>();
vi.mock("@/features/auth/passkeys/invisibleTurnstile", () => ({
  solveInvisibleTurnstile: () => solveInvisibleTurnstile(),
}));

vi.mock("@/features/auth/passkeys/webauthn", () => ({
  getAssertion: (options: unknown) => getAssertion(options),
  passkeysSupported: () => passkeysSupported(),
}));

// The whole assertion the ceremony serialises, so the spec asserts on the payload the form really
// carries rather than on a fragment of it.
const SERIALIZED_ASSERTION = {
  id: "credential-1",
  rawId: "AQID",
  type: "public-key",
  authenticatorAttachment: null,
  response: {
    clientDataJSON: "BAUG",
    authenticatorData: "BwgJ",
    signature: "CgsM",
    userHandle: null,
  },
  clientExtensionResults: {},
};

const { default: PasskeyVerification } =
  await import("@/features/auth/verification/PasskeyVerification");

const props = {
  cancel: STEP_UP_CANCEL,
  title: "検証",
  heading: "検証",
  description: "パスキーで認証してください。",
  errors: [],
  panel: {
    options_url: "/verification/passkey/options?ri=jp",
    verification_url: "/verification/passkey?ri=jp",
    region: "jp", identifier_param: null, field: null,
    turnstile_site_key: "public-key", turnstile_error_message: "Turnstile failed",
    submit_label: "パスキーで認証",
  },
  back: { label: "戻る", href: "/verification?ri=jp" },
};

let container: HTMLDivElement;
let root: Root;
const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

const click = async () => {
  const button = container.querySelector("button");

  await act(async () => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

beforeEach(() => {
  solveInvisibleTurnstile.mockResolvedValue("test-only");
  vi.stubGlobal("location", { href: "", reload: vi.fn() });
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  vi.restoreAllMocks();
  getAssertion.mockReset();
  passkeysSupported.mockReset();
  solveInvisibleTurnstile.mockReset();
  vi.unstubAllGlobals();
});

describe("PasskeyVerification interaction", () => {
  it("submits the serialized assertion when the authenticator answers", async () => {
    passkeysSupported.mockReturnValue(true);
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    const fetchMock = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(new Response(JSON.stringify({ options: { challenge: "abc" }, challenge_id: "challenge-1" }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ status: "ok", redirect_url: "/verification/handoff?ri=jp" }), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    mount(<PasskeyVerification {...props} />);
    await click();
    expect(getAssertion).toHaveBeenCalledWith({ challenge: "abc" });
    expect(fetchMock.mock.calls[0]?.[0]).toBe(props.panel.options_url);
    expect(fetchMock.mock.calls[1]?.[0]).toBe(props.panel.verification_url);
    expect(JSON.parse(String(fetchMock.mock.calls[1]?.[1]?.body))).toEqual({
      challenge_id: "challenge-1", credential: SERIALIZED_ASSERTION, ri: "jp",
    });
    expect(window.location.href).toBe("/verification/handoff?ri=jp");
  });

  it("refuses to start when the browser has no WebAuthn support", async () => {
    passkeysSupported.mockReturnValue(false);
    mount(<PasskeyVerification {...props} />);

    await click();

    expect(getAssertion).not.toHaveBeenCalled();
    expect(solveInvisibleTurnstile).not.toHaveBeenCalled();
    expect(container.textContent).toContain("このブラウザはPasskeyに対応していません");
  });

  it("refuses an options response with a missing challenge", async () => {
    passkeysSupported.mockReturnValue(true);
    vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify({ options: {} }), { status: 200 })));
    mount(<PasskeyVerification {...props} />);
    await click();
    expect(getAssertion).not.toHaveBeenCalled();
    expect(container.textContent).toContain("オプションの取得に失敗しました");
  });

  it("reports a cancelled ceremony without submitting", async () => {
    passkeysSupported.mockReturnValue(true);
    getAssertion.mockRejectedValue(new DOMException("cancelled", "NotAllowedError"));
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify({ options: { challenge: "abc" }, challenge_id: "challenge-1" }), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    mount(<PasskeyVerification {...props} />);

    await click();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(container.textContent).toContain("認証がキャンセルされました");
  });
});
