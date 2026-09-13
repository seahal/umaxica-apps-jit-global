import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  jsonResponse as httpJsonResponse,
  requestBody,
  stubFetchQueue,
} from "../../../support/http";
import { containing } from "../../../support/matchers";
import { present } from "../../../support/present";

// Unlike signin_screens.test.tsx (static markup only), these tests mount the components and fire
// real DOM events, which is the only way to reach the submit, resend and WebAuthn handlers that
// moved out of Stimulus.
const post = vi.fn();
const patch = vi.fn();
const setData = vi.fn();

vi.mock("@inertiajs/react", () => ({
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData,
    post,
    patch,
    processing: false,
  }),
}));

import type { getAssertion as realGetAssertion } from "@/features/auth/passkeys/webauthn";

// Typed from the real export, so a mocked answer that does not match what the module promises is a
// failure here rather than an `any` flowing into the component under test.
const getAssertion = vi.fn<typeof realGetAssertion>();

// The whole assertion the ceremony serialises, so what the spec sends is what the form would.
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
const passkeysSupported = vi.fn<() => boolean>(() => true);

vi.mock("@/features/auth/passkeys/webauthn", () => ({
  getAssertion: (options: unknown) => getAssertion(options),
  passkeysSupported: () => passkeysSupported(),
}));

import type { solveInvisibleTurnstile as realSolveInvisibleTurnstile } from "@/features/auth/turnstile/invisibleToken";

const solveInvisibleTurnstile = vi.fn<typeof realSolveInvisibleTurnstile>();

vi.mock("@/features/auth/turnstile/invisibleToken", () => ({
  solveInvisibleTurnstile: (...args: Parameters<typeof realSolveInvisibleTurnstile>) =>
    solveInvisibleTurnstile(...args),
}));

const { default: SignInEmailEdit } = await import("@/features/auth/SignInEmailEdit");
const { default: EmailSignInForm } = await import("@/features/auth/signin/EmailSignInForm");
const { default: EmailPassCodeForm } = await import("@/features/auth/signin/EmailPassCodeForm");
const { default: SecretSignInForm } = await import("@/features/auth/signin/SecretSignInForm");
const { default: TotpChallengeForm } = await import("@/features/auth/signin/TotpChallengeForm");
const { default: OtpResendButton } = await import("@/features/auth/signin/OtpResendButton");
const { default: PasskeySignInPanel } = await import("@/features/auth/signin/PasskeySignInPanel");
const { default: StepUpPasskeyScreen } = await import("@/features/auth/signin/StepUpPasskeyScreen");
const { csrfToken } = await import("@/features/auth/signin/csrf");
const { PASSKEY_MESSAGES } = await import("@/features/auth/passkeys/messages");

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

// React tracks the previous value of a controlled input, so assigning `value` directly is ignored.
// Going through the prototype setter clears that tracker, which is what a real keystroke does.
const type = (selector: string, value: string) => {
  const input = container.querySelector<HTMLInputElement>(selector);
  const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
  act(() => {
    if (input && descriptor?.set) {
      descriptor.set.call(input, value);
      input.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });
};

const click = (selector: string) => {
  const button = container.querySelector<HTMLButtonElement>(selector);
  expect(button).not.toBeNull();
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

const flush = async () => {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
  });
};

declare global {
  // React reads this flag off the global object to decide whether `act` is allowed.
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

// The production code only reads `status` and `json()`, but building a real Response keeps the stub
// assignable to `fetch` without asserting a hand-written object into the type.
const jsonResponse = (status: number, payload: unknown): Response =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });

const stubFetch = (status: number, payload: unknown) =>
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => jsonResponse(status, payload)),
  );

const turnstile = { site_key: "site-key", mode: "render" as const, action: null, cdata: null };
const backLink = { label: "もどる", href: "/sign/in?ri=jp" };

beforeEach(() => {
  document.head.innerHTML =
    '<meta name="csrf-token" content="csrf-value"><script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';
  window.turnstile = {
    render: vi.fn((_container: HTMLElement, options: { callback?: (token: string) => void }) => {
      options.callback?.("turnstile-token");
      return "widget-1";
    }),
    execute: vi.fn(),
    remove: vi.fn(),
  };
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  document.head.innerHTML = "";
  delete window.turnstile;
  vi.clearAllMocks();
  vi.useRealTimers();
});

describe("csrf token", () => {
  it("reads the token from the document rather than from a prop", () => {
    mount(<div />);

    expect(csrfToken()).toBe("csrf-value");

    document.head.innerHTML = "";

    expect(csrfToken()).toBe("");
  });
});

describe("email sign-in form interaction", () => {
  const props = {
    title: "メールでログイン",
    description: "免責事項",
    form: {
      action: "/sign/in/email",
      method: "post",
      pt: null,
      address_field: {
        scope: "client_email",
        field: "address",
        name: "client_email[address]",
        label: "メールアドレス",
        placeholder: "name@example.com",
      },
      submit_label: "送信する",
    },
    turnstile,
    form_errors: [],
    back_link: backLink,
  };

  it("keeps the verb the route expects and sends the address under its Rails wrapper", () => {
    mount(<EmailSignInForm {...props} />);

    type("input[type=email]", "someone@example.com");

    expect(setData).toHaveBeenCalledWith("client_email", { address: "someone@example.com" });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).toHaveBeenCalledWith("/sign/in/email");
  });
});

describe("pass code form interaction", () => {
  const props = {
    title: "認証コード入力",
    description: "メールアドレスに届きます",
    form: {
      action: "/sign/in/email",
      method: "patch",
      pt: "signed-pt",
      pass_code_field: {
        scope: "client_email",
        field: "pass_code",
        name: "client_email[pass_code]",
        label: "認証コード",
        placeholder: "6桁の数字を入力",
        max_length: 6,
        autocomplete: "one-time-code",
        inputmode: "numeric" as const,
        pattern: "[0-9]*",
      },
      submit_label: "送信する",
    },
    otp_resend: {
      endpoint: "/web/v0/in/email/otp",
      state: "resend-state",
      button_label: "再送する",
      sent_message: "送信しました",
      too_soon_message: "しばらくお待ちください",
      failed_message: "失敗しました",
    },
    turnstile,
    form_errors: [],
    delivery_help: "届かない場合",
    back_link: backLink,
  };

  it("submits the code with PATCH, the verb the route expects", () => {
    mount(<EmailPassCodeForm {...props} />);

    type("input[type=text]", "123456");

    expect(setData).toHaveBeenCalledWith("client_email", { pass_code: "123456" });

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(patch).toHaveBeenCalledWith("/sign/in/email");
  });

  it("clears the code field when the server confirms a resend", async () => {
    stubFetch(200, { resendable: true });

    mount(<EmailPassCodeForm {...props} />);
    click("button[type=button]");
    await flush();

    expect(setData).toHaveBeenCalledWith("client_email", { pass_code: "" });
    vi.unstubAllGlobals();
  });
});

describe("otp resend button", () => {
  const resend = {
    endpoint: "/web/v0/in/email/otp",
    state: "resend-state",
    button_label: "再送する",
    sent_message: "送信しました",
    too_soon_message: "しばらくお待ちください",
    failed_message: "失敗しました",
  };

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("posts the resend state with the CSRF header and reports success", async () => {
    stubFetch(200, { resendable: true });
    const onResent = vi.fn();
    mount(
      <OtpResendButton
        resend={resend}
        onResent={onResent}
      />,
    );

    click("button");
    await flush();

    expect(onResent).toHaveBeenCalled();
    expect(container.querySelector("p")?.textContent).toBe("送信しました");
    const [, init] = present(vi.mocked(fetch).mock.calls[0], "the first fetch call");
    expect(present(init, "the request options")).toMatchObject({
      method: "POST",
      headers: containing({ "X-CSRF-Token": "csrf-value" }),
    });
  });

  it("counts down and blocks a second press while the server says it is too soon", async () => {
    vi.useFakeTimers();
    stubFetch(429, { retry_after: 2 });
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await act(async () => {
      await Promise.resolve();
      await Promise.resolve();
    });

    const button = container.querySelector("button");

    expect(button?.disabled).toBe(true);
    expect(button?.textContent).toContain("(2s)");

    act(() => {
      vi.advanceTimersByTime(1000);
    });

    expect(container.querySelector("button")?.textContent).toContain("(1s)");

    act(() => {
      vi.advanceTimersByTime(1000);
    });

    expect(container.querySelector("button")?.disabled).toBe(false);
  });

  it("resets immediately when the server reports no remaining wait", async () => {
    stubFetch(429, {});
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("button")?.disabled).toBe(false);
    expect(container.querySelector("p")?.textContent).toBe("しばらくお待ちください");
  });

  it("reports a failure for any other answer", async () => {
    stubFetch(500, {});
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("p")?.textContent).toBe("失敗しました");
  });

  it("reports a failure when the request itself cannot be made", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new Error("offline");
      }),
    );
    mount(
      <OtpResendButton
        resend={resend}
        onResent={vi.fn()}
      />,
    );

    click("button");
    await flush();

    expect(container.querySelector("p")?.textContent).toBe("失敗しました");
  });
});

describe("passkey sign-in panel", () => {
  const props = {
    options_url: "/sign/in/passkey/options?ri=jp",
    verification_url: "/sign/in/passkey/verification?ri=jp",
    region: "jp",
    identifier_param: "identifier",
    turnstile_site_key: "stealth-key",
    turnstile_error_message: "検証に失敗しました",
    field: { label: "メールアドレス", placeholder: "name@example.com" },
    submit_label: "パスキーでログイン",
  };

  const typeIdentifier = (value: string) => type("input#identifier", value);

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("refuses to start on a browser without WebAuthn", async () => {
    passkeysSupported.mockReturnValueOnce(false);
    mount(<PasskeySignInPanel {...props} />);
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("refuses to start without an identifier", async () => {
    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("   ");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.identifierRequired,
    );
  });

  it("uses the default challenge copy when the page supplied none", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    const fetchMock = stubFetchQueue(
      httpJsonResponse({ challenge_id: "challenge-1", options: { a: 1 } }),
      httpJsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(
      <PasskeySignInPanel
        {...props}
        turnstile_error_message=""
      />,
    );
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(solveInvisibleTurnstile).toHaveBeenCalledWith(
      "stealth-key",
      expect.stringMatching(/./u),
      expect.anything(),
    );
    expect(requestBody(fetchMock, 0)).toMatchObject({ identifier: "someone@example.com" });
  });

  it("falls back when a failed options response carries no content type", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        headers: new Headers(),
        json: async () => ({}),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("omits the region when the page carries none", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    const fetchMock = stubFetchQueue(
      httpJsonResponse({ challenge_id: "challenge-1", options: { a: 1 } }),
      httpJsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(
      <PasskeySignInPanel
        {...props}
        region=""
      />,
    );
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(requestBody(fetchMock, 0)).not.toHaveProperty("ri");
    expect(window.location.href).toBe("/identity");
  });

  it("uses the ceremony fallback when the options response names no error", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        headers: new Headers({ "content-type": "application/json" }),
        json: async () => ({}),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("refuses options that name no challenge", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    stubFetchQueue(httpJsonResponse({ options: { a: 1 } }));

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("carries the challenge token and the assertion to the server, then follows its redirect", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);

    const fetchMock = stubFetchQueue(
      httpJsonResponse({ challenge_id: "challenge-1", options: { a: 1 } }),
      httpJsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    const location = { href: "", reload: vi.fn() };
    vi.stubGlobal("location", location);

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(requestBody(fetchMock, 0)).toMatchObject({
      identifier: "someone@example.com",
      "cf-turnstile-response": "turnstile-token",
      ri: "jp",
    });
    expect(requestBody(fetchMock, 1)).toMatchObject({
      challenge_id: "challenge-1",
      credential: { id: "credential-1" },
    });
    expect(window.location.href).toBe("/identity");
  });

  it("follows the second-factor redirect the server asks for", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ status: "totp_required", redirect_url: "/challenge" }),
        }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(window.location.href).toBe("/challenge");
  });

  it("rejects an answer it does not recognise instead of assuming success", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ status: "surprise", redirect_url: "/nowhere" }),
        }),
    );
    vi.stubGlobal("location", { href: "", reload: vi.fn() });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.unexpectedResponse,
    );
  });

  it("surfaces the server's own message when the options request is refused", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 422,
        headers: new Headers({ "content-type": "application/json" }),
        json: async () => ({ error: "識別子が必要です" }),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe("識別子が必要です");
  });

  it("reloads when the session is gone rather than reporting a ceremony failure", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 401,
        headers: new Headers({ "content-type": "text/html" }),
        json: async () => ({}),
      }),
    );
    const reload = vi.fn();
    vi.stubGlobal("location", { href: "", reload });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(reload).toHaveBeenCalled();
    expect(container.querySelector("[role=alert]")).toBeNull();
  });

  it("falls back to the ceremony message for a non-JSON refusal", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: false,
        status: 500,
        headers: new Headers({ "content-type": "text/html" }),
        json: async () => ({}),
      }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsFailed,
    );
  });

  it("reports a refused verification with the ceremony message", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: false,
          status: 422,
          headers: new Headers({ "content-type": "text/html" }),
          json: async () => ({}),
        }),
    );

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.verificationFailed,
    );
  });

  it("reloads instead of continuing when the verification session is gone", async () => {
    solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({
          ok: true,
          headers: new Headers({ "content-type": "application/json" }),
          json: async () => ({ challenge_id: "c", options: {} }),
        })
        .mockResolvedValueOnce({
          ok: false,
          status: 302,
          headers: new Headers({ "content-type": "text/html" }),
          json: async () => ({}),
        }),
    );
    const reload = vi.fn();
    vi.stubGlobal("location", { href: "", reload });

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(reload).toHaveBeenCalled();
  });

  it("reports a challenge that could not be presented rather than proceeding without one", async () => {
    solveInvisibleTurnstile.mockRejectedValue(new Error("検証に失敗しました"));

    mount(<PasskeySignInPanel {...props} />);
    typeIdentifier("someone@example.com");
    click("button");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe("検証に失敗しました");
  });
});

describe("step-up passkey screen", () => {
  const props = {
    title: "パスキーで確認",
    description: "登録済みのパスキー",
    form: {
      action: "/sign/in/challenge/passkey",
      authenticity_token: "csrf-value",
      param_scope: "mfa_passkey_form",
      challenge_id: "challenge-1",
      request_options: { challenge: "abc" },
      submit_label: "認証する",
    },
    back_link: backLink,
  };

  it("refuses to start on a browser without WebAuthn", async () => {
    passkeysSupported.mockReturnValueOnce(false);
    mount(<StepUpPasskeyScreen {...props} />);
    click("button[type=button]");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("refuses to start when the server issued no challenge", async () => {
    mount(
      <StepUpPasskeyScreen
        {...props}
        form={{ ...props.form, request_options: null }}
      />,
    );
    click("button[type=button]");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(
      PASSKEY_MESSAGES.optionsMissing,
    );
  });

  it("puts the assertion in the form and submits it to the server", async () => {
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    const requestSubmit = vi.fn();
    HTMLFormElement.prototype.requestSubmit = requestSubmit;

    mount(<StepUpPasskeyScreen {...props} />);
    click("button[type=button]");
    await flush();

    const field = container.querySelector<HTMLInputElement>(
      'input[name="mfa_passkey_form[credential_json]"]',
    );

    expect(JSON.parse(present(field, "the credential field").value)).toMatchObject({
      id: "credential-1",
    });
    expect(requestSubmit).toHaveBeenCalled();
  });

  it("reports a cancelled ceremony instead of submitting", async () => {
    const cancelled = new Error("cancelled");
    cancelled.name = "NotAllowedError";
    getAssertion.mockRejectedValue(cancelled);

    mount(<StepUpPasskeyScreen {...props} />);
    click("button[type=button]");
    await flush();

    expect(container.querySelector("[role=alert]")?.textContent).toBe(PASSKEY_MESSAGES.cancelled);
  });
});

describe("secret sign-in form interaction", () => {
  const props = {
    title: "パスワードでログイン",
    form: {
      action: "/sign/in/secret",
      method: "post",
      pt: null,
      ri: "jp",
      identifier_field: {
        scope: "secret_credential_login_form",
        field: "identifier",
        name: "secret_credential_login_form[identifier]",
        label: "メールアドレス",
        placeholder: "name@example.com",
      },
      secret_field: {
        scope: "secret_credential_login_form",
        field: "secret_credential_value",
        name: "secret_credential_login_form[secret_credential_value]",
        label: "パスワード",
        placeholder: "••••••••••••••••",
      },
      submit_label: "送信する",
    },
    hints: null,
    error_heading: "入力を確認してください",
    form_errors: [] as string[],
    turnstile,
    back_link: backLink,
  };

  it("posts the identifier and secret under the Rails wrapper", async () => {
    mount(<SecretSignInForm {...props} />);
    await flush();

    type('input[name="secret_credential_login_form[identifier]"]', "someone@example.test");
    type('input[name="secret_credential_login_form[secret_credential_value]"]', "s3cret");

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(setData).toHaveBeenCalled();
    expect(post).toHaveBeenCalledWith("/sign/in/secret");
  });
});

describe("totp challenge form interaction", () => {
  const props = {
    title: "二段階認証",
    description: "認証アプリのコード",
    form: {
      action: "/sign/in/challenge/totp",
      method: "post",
      token_field: {
        scope: "totp_challenge_form",
        field: "token",
        name: "totp_challenge_form[token]",
        label: "コード",
        placeholder: "6桁",
        max_length: 6,
        inputmode: "numeric" as const,
        help: "認証アプリを開いてください",
      },
      submit_label: "確認する",
    },
    error_heading: "入力を確認してください",
    form_errors: [] as string[],
    turnstile,
    back_link: backLink,
  };

  it("posts the one-time code", async () => {
    mount(<TotpChallengeForm {...props} />);
    await flush();

    type('input[name="totp_challenge_form[token]"]', "123456");

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(setData).toHaveBeenCalledWith("totp_challenge_form", { token: "123456" });
    expect(post).toHaveBeenCalledWith("/sign/in/challenge/totp");
  });
});

describe("email one-time code edit interaction", () => {
  const props = {
    title: "コードの入力",
    description: "説明",
    action: "/sign/in/email",
    pt: "token",
    field_label: "コード",
    field_placeholder: "000000",
    submit_label: "確認",
    delivery_help: "届かない場合",
    return_link: { label: "もどる", href: "/sign/in/email/new" },
    resend: {
      endpoint: "/web/v0/in/email/otp",
      state: "resend-state",
      messages: {
        button_label: "再送信",
        sent_message: "送信しました",
        too_soon_message: "しばらく待ってください",
        failed_message: "失敗しました",
      },
    },
    turnstile,
  };

  it("patches the one-time code", async () => {
    mount(<SignInEmailEdit {...props} />);
    await flush();

    type('input[name="user_email[pass_code]"]', "654321");

    act(() => {
      container
        .querySelector("form")
        ?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(setData).toHaveBeenCalled();
    expect(patch).toHaveBeenCalledWith("/sign/in/email");
  });

  it("clears the typed code when the server confirms a resend", async () => {
    stubFetch(200, { resendable: true });
    mount(<SignInEmailEdit {...props} />);
    await flush();

    click("button[type=button]");
    await flush();

    expect(setData).toHaveBeenCalledWith("user_email", { pass_code: "" });
    vi.unstubAllGlobals();
  });
});
