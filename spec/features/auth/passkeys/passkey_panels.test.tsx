// The three fetch-driven passkey ceremonies, driven end to end.
//
// Each one talks to the same two server endpoints the Stimulus controllers did, so the assertions
// are on what was posted and on what the visitor is told when a step refuses. The WebAuthn layer is
// real here -- only `navigator.credentials` and the Turnstile solve are stubbed -- so the encoding
// the server verifies is covered by the same run.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { solveInvisibleTurnstile as realSolve } from "@/features/auth/passkeys/invisibleTurnstile";
import type { StepUpPasskeyFormProps } from "@/features/auth/passkeys/StepUpPasskeyForm";

import {
  jsonResponse,
  requestBody,
  requestUrl,
  stubFetchQueue,
  textResponse,
} from "../../../support/http";
import { mount } from "../../../support/react";
import {
  assertionCredential,
  attestationCredential,
  credentialError,
  stubCredentialsApi,
} from "../../../support/webauthn";

const solveInvisibleTurnstile = vi.fn<typeof realSolve>();

vi.mock("@/features/auth/passkeys/invisibleTurnstile", () => ({
  solveInvisibleTurnstile: (...args: Parameters<typeof realSolve>) =>
    solveInvisibleTurnstile(...args),
}));

const { default: PasskeyAuthenticationPanel } =
  await import("@/features/auth/passkeys/PasskeyAuthenticationPanel");
type PasskeyAuthenticationPanelProps = Parameters<typeof PasskeyAuthenticationPanel>[0];
const { default: PasskeyRegistrationPanel } =
  await import("@/features/auth/passkeys/PasskeyRegistrationPanel");
const { default: StepUpPasskeyForm } = await import("@/features/auth/passkeys/StepUpPasskeyForm");
const { PASSKEY_MESSAGES, TURNSTILE_DEFAULT_ERROR } =
  await import("@/features/auth/passkeys/messages");

const CREATION_OPTIONS = {
  challenge: "Y2hhbGxlbmdl",
  rp: { name: "Umaxica", id: "example.test" },
  user: { id: "dXNlci1pZA", name: "someone@example.test", displayName: "Someone" },
  pubKeyCredParams: [{ type: "public-key", alg: -7 }],
};

const REQUEST_OPTIONS = { challenge: "Y2hhbGxlbmdl" };

let credentials: ReturnType<typeof stubCredentialsApi>;

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  credentials = stubCredentialsApi();
  solveInvisibleTurnstile.mockResolvedValue("turnstile-token");
});

afterEach(() => {
  document.head.innerHTML = "";
  vi.unstubAllGlobals();
  vi.clearAllMocks();
});

const stubLocation = () => {
  const location = { href: "", reload: vi.fn() };
  vi.stubGlobal("location", location);
  return location;
};

describe("PasskeyAuthenticationPanel", () => {
  const props = {
    options_url: "/sign/in/passkey/options",
    verification_url: "/sign/in/passkey/verification",
    region: "jp",
    identifier_param: "identifier",
    turnstile_site_key: "site-key",
    turnstile_error_message: "検証に失敗しました",
    field: {
      label: "メールアドレスまたはID",
      placeholder: "someone@example.test",
      min_length: 3,
      max_length: 255,
      pattern: ".+",
    },
    submit_label: "パスキーでログイン",
  };

  const start = async (
    overrides: Partial<PasskeyAuthenticationPanelProps> = {},
    identifier = "someone@example.test",
  ) => {
    const screen = mount(
      <PasskeyAuthenticationPanel
        {...props}
        {...overrides}
      />,
    );
    if (identifier !== "") {
      screen.type("input#identifier", identifier);
    }
    screen.click("button");
    await screen.flush();
    return screen;
  };

  it("renders the field the server described", () => {
    const screen = mount(<PasskeyAuthenticationPanel {...props} />);
    const input = screen.container.querySelector<HTMLInputElement>("input#identifier");

    expect(input?.placeholder).toBe("someone@example.test");
    expect(input?.minLength).toBe(3);
    expect(input?.maxLength).toBe(255);
    expect(screen.text("label")).toBe("メールアドレスまたはID");
    expect(screen.text("button")).toBe("パスキーでログイン");
  });

  // The org normal ceremony runs after Entra ID has already selected the
  // operator, so the panel neither asks for an identifier nor sends one: the
  // server reads the actor from its own pending transaction and would ignore
  // anything here anyway.
  it("asks for no identifier when an earlier stage already chose the actor", () => {
    const screen = mount(
      <PasskeyAuthenticationPanel
        {...props}
        identifier_param={null}
        field={null}
      />,
    );

    expect(screen.container.querySelector("input#identifier")).toBeNull();
    expect(screen.container.querySelector("label")).toBeNull();
    expect(screen.text("button")).toBe("パスキーでログイン");
  });

  it("starts without an identifier, and sends none, when the server named no field", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "challenge-1", options: REQUEST_OPTIONS }),
      jsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    stubLocation();

    await start({ identifier_param: null, field: null }, "");

    expect(requestBody(fetchMock, 0)).toEqual({
      "cf-turnstile-response": "turnstile-token",
      ri: "jp",
    });
  });

  it("refuses to start on a browser without WebAuthn", async () => {
    vi.stubGlobal("PublicKeyCredential", undefined);
    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.unsupported);
    expect(solveInvisibleTurnstile).not.toHaveBeenCalled();
  });

  it("refuses to start on a blank identifier", async () => {
    const screen = await start({}, "   ");

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.identifierRequired);
  });

  it("carries the token, identifier and assertion to the server, then follows its redirect", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "challenge-1", options: REQUEST_OPTIONS }),
      jsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    const location = stubLocation();

    await start();

    expect(requestUrl(fetchMock, 0)).toBe("/sign/in/passkey/options");
    expect(requestBody(fetchMock, 0)).toEqual({
      identifier: "someone@example.test",
      "cf-turnstile-response": "turnstile-token",
      ri: "jp",
    });
    expect(requestUrl(fetchMock, 1)).toBe("/sign/in/passkey/verification");
    expect(requestBody(fetchMock, 1)).toMatchObject({
      challenge_id: "challenge-1",
      credential: { id: "cred-id", rawId: "AQID" },
      ri: "jp",
    });
    expect(location.href).toBe("/identity");
  });

  it("omits the region when the page carries none", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "challenge-1", options: REQUEST_OPTIONS }),
      jsonResponse({ status: "ok", redirect_url: "/identity" }),
    );
    stubLocation();

    await start({ region: "" });

    expect(requestBody(fetchMock, 0)).not.toHaveProperty("ri");
  });

  it("solves the challenge with the default message when the page supplied none", async () => {
    stubFetchQueue(jsonResponse({ challenge_id: "c", options: REQUEST_OPTIONS }));
    credentials.get.mockResolvedValue(assertionCredential());
    stubLocation();

    await start({ turnstile_error_message: "" });

    expect(solveInvisibleTurnstile).toHaveBeenCalledWith(
      "site-key",
      TURNSTILE_DEFAULT_ERROR,
      expect.any(HTMLElement),
    );
  });

  it("follows the second-factor redirect the server asks for", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: REQUEST_OPTIONS }),
      jsonResponse({ status: "totp_required", redirect_url: "/challenge" }),
    );
    const location = stubLocation();

    const screen = await start();

    expect(location.href).toBe("/challenge");
    expect(screen.text("p.text-fg-muted")).toBe(PASSKEY_MESSAGES.totpRequired);
  });

  it("rejects an answer it does not recognise instead of assuming success", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: REQUEST_OPTIONS }),
      jsonResponse({ status: "ok" }),
    );
    stubLocation();

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.unexpectedResponse);
  });

  it("refuses options that carry no challenge id", async () => {
    stubFetchQueue(jsonResponse({ options: REQUEST_OPTIONS }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("refuses options that carry no request options", async () => {
    stubFetchQueue(jsonResponse({ challenge_id: "c" }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("surfaces the server's own message when the options request is refused", async () => {
    stubFetchQueue(jsonResponse({ error: "識別子が必要です" }, 422));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe("識別子が必要です");
  });

  it("falls back to the ceremony message for a JSON refusal that names no reason", async () => {
    stubFetchQueue(jsonResponse({}, 422));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("falls back to the ceremony message for a non-JSON refusal", async () => {
    stubFetchQueue(textResponse("<html></html>", 500));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("reloads when the session is gone rather than reporting a ceremony failure", async () => {
    stubFetchQueue(textResponse("<html></html>", 401));
    const location = stubLocation();

    const screen = await start();

    expect(location.reload).toHaveBeenCalled();
    expect(screen.text("[role=alert]")).toBeNull();
  });

  it("reports a refused verification with the ceremony message", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: REQUEST_OPTIONS }),
      textResponse("<html></html>", 422),
    );

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.verificationFailed);
  });

  it("reloads instead of continuing when the verification session is gone", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: REQUEST_OPTIONS }),
      textResponse("<html></html>", 302),
    );
    const location = stubLocation();

    await start();

    expect(location.reload).toHaveBeenCalled();
  });

  it("reports a challenge that could not be presented rather than proceeding without one", async () => {
    solveInvisibleTurnstile.mockRejectedValue(new Error("検証に失敗しました"));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe("検証に失敗しました");
  });

  it("reports a cancelled ceremony under its own name", async () => {
    credentials.get.mockRejectedValue(credentialError("NotAllowedError"));
    stubFetchQueue(jsonResponse({ challenge_id: "c", options: REQUEST_OPTIONS }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.cancelled);
  });
});

describe("PasskeyRegistrationPanel", () => {
  const props = {
    options_url: "/settings/passkeys/options",
    verification_url: "/settings/passkeys/verification",
    turnstile_site_key: "site-key",
    turnstile_error_message: "検証に失敗しました",
    description_label: "デバイス名",
    description_placeholder: "MacBook",
    submit_label: "パスキーを登録",
  };

  const start = async (overrides: Partial<typeof props> = {}, description?: string) => {
    const screen = mount(
      <PasskeyRegistrationPanel
        {...props}
        {...overrides}
      />,
    );
    if (description !== undefined) {
      screen.type("input", description);
    }
    screen.click("button");
    await screen.flush();
    return screen;
  };

  it("refuses to start on a browser without WebAuthn", async () => {
    vi.stubGlobal("PublicKeyCredential", undefined);
    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("carries the token, attestation and description to the server, then follows its redirect", async () => {
    credentials.create.mockResolvedValue(attestationCredential({ transports: ["internal"] }));
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "challenge-1", options: CREATION_OPTIONS }),
      jsonResponse({ redirect_url: "/settings/passkeys" }),
    );
    const location = stubLocation();

    await start({}, "MacBook Pro");

    expect(requestBody(fetchMock, 0)).toEqual({ "cf-turnstile-response": "turnstile-token" });
    expect(requestBody(fetchMock, 1)).toEqual({
      challenge_id: "challenge-1",
      credential: {
        id: "cred-id",
        rawId: "AQID",
        type: "public-key",
        authenticatorAttachment: null,
        response: {
          clientDataJSON: "BAUG",
          attestationObject: "DQ4P",
          transports: ["internal"],
        },
        clientExtensionResults: {},
      },
      description: "MacBook Pro",
    });
    expect(location.href).toBe("/settings/passkeys");
  });

  it("sends an empty transports list when the authenticator reports none", async () => {
    credentials.create.mockResolvedValue(attestationCredential({ transports: null }));
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      jsonResponse({ redirect_url: "/settings/passkeys" }),
    );
    stubLocation();

    await start();

    expect(requestBody(fetchMock, 1)).toMatchObject({
      credential: { response: { transports: [] } },
    });
  });

  it("reloads when the server names no destination", async () => {
    credentials.create.mockResolvedValue(attestationCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      jsonResponse({}),
    );
    const location = stubLocation();

    const screen = await start();

    expect(location.reload).toHaveBeenCalled();
    expect(screen.text("p.text-fg-muted")).toBe(PASSKEY_MESSAGES.registrationComplete);
  });

  it("refuses an answer the authenticator did not shape as an attestation", async () => {
    credentials.create.mockResolvedValue({ id: "c", type: "public-key" });
    stubFetchQueue(jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.registrationFailed);
  });

  it("refuses an empty answer from the authenticator", async () => {
    credentials.create.mockResolvedValue(null);
    stubFetchQueue(jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.registrationFailed);
  });

  it("refuses options that carry no challenge id", async () => {
    stubFetchQueue(jsonResponse({ options: CREATION_OPTIONS }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("refuses options that carry no creation options", async () => {
    stubFetchQueue(jsonResponse({ challenge_id: "c" }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("surfaces the server's own message when the options request is refused", async () => {
    stubFetchQueue(jsonResponse({ error: "登録は許可されていません" }, 422));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe("登録は許可されていません");
  });

  it("falls back to the ceremony message for a JSON refusal that names no reason", async () => {
    stubFetchQueue(jsonResponse({}, 422));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("falls back to the ceremony message for a non-JSON refusal", async () => {
    stubFetchQueue(textResponse("<html></html>", 500));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsFailed);
  });

  it("reloads when the session is gone rather than reporting a ceremony failure", async () => {
    stubFetchQueue(textResponse("<html></html>", 401));
    const location = stubLocation();

    const screen = await start();

    expect(location.reload).toHaveBeenCalled();
    expect(screen.text("[role=alert]")).toBeNull();
  });

  it("reports a refused verification with the registration message", async () => {
    credentials.create.mockResolvedValue(attestationCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      textResponse("<html></html>", 422),
    );

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.registrationFailed);
  });

  it("reloads instead of continuing when the verification session is gone", async () => {
    credentials.create.mockResolvedValue(attestationCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      textResponse("<html></html>", 302),
    );
    const location = stubLocation();

    await start();

    expect(location.reload).toHaveBeenCalled();
  });

  it("names an authenticator that already holds this passkey", async () => {
    credentials.create.mockRejectedValue(credentialError("InvalidStateError"));
    stubFetchQueue(jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.alreadyRegistered);
  });

  it("reports a challenge that could not be presented rather than proceeding without one", async () => {
    solveInvisibleTurnstile.mockRejectedValue(new Error("検証に失敗しました"));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe("検証に失敗しました");
  });

  it("solves the challenge with the default message when the page supplied none", async () => {
    stubFetchQueue(jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }));
    credentials.create.mockResolvedValue(attestationCredential());
    stubLocation();

    await start({ turnstile_error_message: "" });

    expect(solveInvisibleTurnstile).toHaveBeenCalledWith(
      "site-key",
      TURNSTILE_DEFAULT_ERROR,
      expect.any(HTMLElement),
    );
  });
});

describe("StepUpPasskeyForm", () => {
  const nativeRequestSubmit = HTMLFormElement.prototype.requestSubmit;

  afterEach(() => {
    HTMLFormElement.prototype.requestSubmit = nativeRequestSubmit;
  });

  const props = {
    action: "/verification/passkey",
    param_scope: "verification",
    challenge_id: "challenge-1",
    request_options: REQUEST_OPTIONS,
    submit_label: "認証する",
  };

  const start = async (overrides: Partial<StepUpPasskeyFormProps> = {}) => {
    const screen = mount(
      <StepUpPasskeyForm
        {...props}
        {...overrides}
      />,
    );
    screen.click("button[type=button]");
    await screen.flush();
    return screen;
  };

  it("carries the server's challenge and the page's CSRF token in the form", () => {
    const screen = mount(<StepUpPasskeyForm {...props} />);
    const form = screen.container.querySelector("form");

    expect(form?.getAttribute("action")).toBe("/verification/passkey");
    expect(
      screen.container.querySelector<HTMLInputElement>('input[name="authenticity_token"]')?.value,
    ).toBe("csrf-value");
    expect(
      screen.container.querySelector<HTMLInputElement>('input[name="verification[challenge_id]"]')
        ?.value,
    ).toBe("challenge-1");
  });

  it("refuses to start on a browser without WebAuthn", async () => {
    vi.stubGlobal("PublicKeyCredential", undefined);
    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("refuses to start when the server issued no options", async () => {
    const screen = await start({ request_options: null });

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsMissing);
  });

  it("refuses to start when the server issued no challenge id", async () => {
    const screen = await start({ challenge_id: "" });

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.optionsMissing);
  });

  it("writes the assertion into the form before it submits", async () => {
    credentials.get.mockResolvedValue(assertionCredential());
    // What the server receives is whatever the field holds at submit time, so the value is read
    // there rather than after the render that follows.
    let submitted: string | undefined;
    const requestSubmit = vi.fn(function submit(this: HTMLFormElement) {
      submitted = this.querySelector<HTMLInputElement>(
        'input[name="verification[credential_json]"]',
      )?.value;
    });
    HTMLFormElement.prototype.requestSubmit = requestSubmit;

    const screen = await start();

    expect(requestSubmit).toHaveBeenCalled();
    expect(submitted).toEqual(expect.any(String));
    expect(JSON.parse(String(submitted))).toMatchObject({ id: "cred-id", rawId: "AQID" });
    expect(screen.text("p.text-fg-muted")).toBe(PASSKEY_MESSAGES.verifying);
  });

  it("reports a cancelled ceremony instead of submitting", async () => {
    credentials.get.mockRejectedValue(credentialError("NotAllowedError"));
    const requestSubmit = vi.fn();
    HTMLFormElement.prototype.requestSubmit = requestSubmit;

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.cancelled);
    expect(requestSubmit).not.toHaveBeenCalled();
  });

  it("reports a security error under its own name", async () => {
    credentials.get.mockRejectedValue(credentialError("SecurityError"));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.securityError);
  });
});
