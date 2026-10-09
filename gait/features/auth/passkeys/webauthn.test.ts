// The encoding the server verifies. A credential that reaches the server in the wrong shape fails
// signature verification, so every branch that decides what is sent is exercised against a
// credential shaped the way an authenticator answers.
import { afterEach, describe, expect, it, vi } from "vitest";

import {
  bufferToBase64url,
  createCredential,
  getAssertion,
  isAttestationCredential,
  passkeysSupported,
} from "@/features/auth/passkeys/webauthn";

import {
  CREATION_OPTIONS,
  REQUEST_OPTIONS,
  assertionCredential,
  attestationCredential,
  stubCredentialsApi,
} from "../../../support/webauthn";

const buffer = (bytes: number[]): ArrayBuffer => new Uint8Array(bytes).buffer;

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("bufferToBase64url", () => {
  it("encodes without padding and with the url-safe alphabet", () => {
    expect(bufferToBase64url(buffer([1, 2, 3]))).toBe("AQID");
    // 0xfb 0xff encodes to "+/" in standard base64, which must not survive into a url.
    expect(bufferToBase64url(buffer([251, 255]))).toBe("-_8");
    expect(bufferToBase64url(buffer([]))).toBe("");
  });
});

describe("passkeysSupported", () => {
  it("is true only when the platform publishes PublicKeyCredential", () => {
    stubCredentialsApi();

    expect(passkeysSupported()).toBe(true);

    vi.stubGlobal("PublicKeyCredential", undefined);

    expect(passkeysSupported()).toBe(false);
  });
});

describe("isAttestationCredential", () => {
  it("rejects a credential missing the parts an attestation is read from", () => {
    expect(isAttestationCredential({ id: "c", type: "public-key" })).toBe(false);
    expect(isAttestationCredential({ id: "c", type: "public-key", rawId: buffer([1]) })).toBe(
      false,
    );
    expect(
      isAttestationCredential({
        id: "c",
        type: "public-key",
        rawId: buffer([1]),
        response: null,
      }),
    ).toBe(false);
    expect(
      isAttestationCredential({
        id: "c",
        type: "public-key",
        rawId: buffer([1]),
        response: { clientDataJSON: buffer([1]) },
      }),
    ).toBe(false);
  });

  it("accepts a credential carrying an attestation response", () => {
    expect(isAttestationCredential(attestationCredential())).toBe(true);
  });
});

describe("getAssertion", () => {
  it("serialises the assertion the server verifies", async () => {
    const { get } = stubCredentialsApi();
    get.mockResolvedValue(assertionCredential());

    await expect(getAssertion(REQUEST_OPTIONS)).resolves.toEqual({
      id: "cred-id",
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
    });
  });

  it("encodes the user handle and attachment the authenticator reported", async () => {
    const { get } = stubCredentialsApi();
    get.mockResolvedValue(
      assertionCredential({
        authenticatorAttachment: "platform",
        userHandle: buffer([16, 17]),
        clientExtensionResults: { appid: true },
      }),
    );

    const assertion = await getAssertion(REQUEST_OPTIONS);

    expect(assertion.authenticatorAttachment).toBe("platform");
    expect(assertion.response["userHandle"]).toBe("EBE");
    expect(assertion.clientExtensionResults).toEqual({ appid: true });
  });

  it("refuses an empty answer instead of posting nothing to the server", async () => {
    const { get } = stubCredentialsApi();
    get.mockResolvedValue(null);

    await expect(getAssertion(REQUEST_OPTIONS)).rejects.toThrow(
      "No credential was returned by the authenticator",
    );
  });

  it("refuses a credential that is not a WebAuthn assertion", async () => {
    const { get } = stubCredentialsApi();
    get.mockResolvedValue({ id: "c", type: "public-key" });

    await expect(getAssertion(REQUEST_OPTIONS)).rejects.toThrow("not a WebAuthn assertion");
  });
});

describe("createCredential", () => {
  it("serialises the attestation, including the transports the server stores", async () => {
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(attestationCredential({ transports: ["usb", "nfc"] }));

    await expect(createCredential(CREATION_OPTIONS)).resolves.toEqual({
      id: "cred-id",
      rawId: "AQID",
      type: "public-key",
      authenticatorAttachment: null,
      response: {
        clientDataJSON: "BAUG",
        attestationObject: "DQ4P",
        transports: ["usb", "nfc"],
      },
      clientExtensionResults: {},
    });
  });

  it("sends an empty transports list when the authenticator reports none", async () => {
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(
      attestationCredential({ transports: null, authenticatorAttachment: "cross-platform" }),
    );

    const attestation = await createCredential(CREATION_OPTIONS);

    expect(attestation.response["transports"]).toEqual([]);
    expect(attestation.authenticatorAttachment).toBe("cross-platform");
  });

  it("refuses an empty answer instead of posting nothing to the server", async () => {
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(null);

    await expect(createCredential(CREATION_OPTIONS)).rejects.toThrow(
      "No credential was returned by the authenticator",
    );
  });

  it("refuses a credential that is not a WebAuthn attestation", async () => {
    const { create } = stubCredentialsApi();
    create.mockResolvedValue(assertionCredential());

    await expect(createCredential(CREATION_OPTIONS)).rejects.toThrow("not a WebAuthn attestation");
  });
});
