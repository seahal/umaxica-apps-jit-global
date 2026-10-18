import { within } from "@testing-library/react";
// The passkey requirement of the sign-up checkpoint.
//
// The checkpoint version travels with the attestation because the server re-validates it before
// clearing the requirement, so it is asserted on every successful post. This page has no Turnstile
// step: the options endpoint verifies no token, and inventing one here would test something the
// server does not check.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { PASSKEY_MESSAGES } from "@/features/auth/passkeys/messages";
import SignUpPasskeyRegistration from "@/features/auth/signup/SignUpPasskeyRegistration";

import {
  jsonResponse,
  requestBody,
  requestUrl,
  stubFetchQueue,
  textResponse,
} from "../../../support/http";
import { mount } from "../../../support/react";
import {
  attestationCredential,
  credentialError,
  stubCredentialsApi,
} from "../../../support/webauthn";

const CREATION_OPTIONS = {
  challenge: "Y2hhbGxlbmdl",
  rp: { name: "Umaxica", id: "example.test" },
  user: { id: "dXNlci1pZA", name: "someone@example.test", displayName: "Someone" },
  pubKeyCredParams: [{ type: "public-key", alg: -7 }],
};

const props = {
  title: "パスキーを登録",
  begin_url: "/sign/up/checkpoint/passkey/options",
  finish_url: "/sign/up/checkpoint/passkey/verification",
  success_redirect_url: "/sign/up/checkpoint",
  checkpoint_version: 3,
  description_label: "デバイス名",
  description_placeholder: "MacBook",
  submit_label: "登録する",
};

let credentials: ReturnType<typeof stubCredentialsApi>;

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  credentials = stubCredentialsApi();
});

afterEach(() => {
  document.head.innerHTML = "";
  vi.unstubAllGlobals();
});

const stubLocation = () => {
  const location = { href: "", reload: vi.fn() };
  vi.stubGlobal("location", location);
  return location;
};

const start = async (overrides: Partial<typeof props> = {}, description?: string) => {
  const screen = mount(
    <SignUpPasskeyRegistration
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

describe("SignUpPasskeyRegistration", () => {
  it("renders the title and the description field the server described", () => {
    const screen = mount(<SignUpPasskeyRegistration {...props} />);

    expect(screen.text("h1")).toBe("パスキーを登録");
    expect(screen.container.querySelector<HTMLInputElement>("input")?.placeholder).toBe("MacBook");
    expect(screen.text("button")).toBe("登録する");
  });

  it("refuses to start on a browser without WebAuthn", async () => {
    vi.stubGlobal("PublicKeyCredential", undefined);
    const screen = await start();

    expect(screen.text("[role=alert]")).toBe(PASSKEY_MESSAGES.unsupported);
  });

  it("carries the attestation, description and checkpoint version, then follows the redirect", async () => {
    credentials.create.mockResolvedValue(attestationCredential({ transports: ["internal"] }));
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "challenge-1", options: CREATION_OPTIONS }),
      jsonResponse({ redirect_url: "/sign/up/checkpoint/next" }),
    );
    const location = stubLocation();

    await start({}, "MacBook Pro");

    expect(requestUrl(fetchMock, 0)).toBe("/sign/up/checkpoint/passkey/options");
    expect(requestBody(fetchMock, 0)).toEqual({});
    expect(requestUrl(fetchMock, 1)).toBe("/sign/up/checkpoint/passkey/verification");
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
      checkpoint_version: 3,
    });
    expect(location.href).toBe("/sign/up/checkpoint/next");
  });

  it("sends an empty transports list when the authenticator reports none", async () => {
    credentials.create.mockResolvedValue(attestationCredential({ transports: null }));
    const fetchMock = stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      jsonResponse({ redirect_url: "/next" }),
    );
    stubLocation();

    await start();

    expect(requestBody(fetchMock, 1)).toMatchObject({
      credential: { response: { transports: [] } },
    });
  });

  it("falls back to the page's own destination when the server names none", async () => {
    credentials.create.mockResolvedValue(attestationCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      jsonResponse({}),
    );
    const location = stubLocation();

    const screen = await start();

    expect(location.href).toBe("/sign/up/checkpoint");
    expect(within(screen.container).getByRole("status").textContent).toBe(
      PASSKEY_MESSAGES.registrationComplete,
    );
  });

  it("reloads when neither the server nor the page names a destination", async () => {
    credentials.create.mockResolvedValue(attestationCredential());
    stubFetchQueue(
      jsonResponse({ challenge_id: "c", options: CREATION_OPTIONS }),
      jsonResponse({}),
    );
    const location = stubLocation();

    await start({ success_redirect_url: "" });

    expect(location.reload).toHaveBeenCalled();
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
    stubFetchQueue(jsonResponse({ error: "チェックポイントが期限切れです" }, 422));

    const screen = await start();

    expect(screen.text("[role=alert]")).toBe("チェックポイントが期限切れです");
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
});
