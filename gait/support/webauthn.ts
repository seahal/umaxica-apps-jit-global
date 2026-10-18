// Credentials shaped the way an authenticator answers, for the specs that drive a passkey ceremony.
//
// `navigator.credentials` is not implemented in jsdom, so it is stubbed; what it answers still has
// to satisfy the same checks the production code runs on a real credential, or the spec proves
// nothing about the path it claims to cover.
import { type Mock, vi } from "vitest";

const buffer = (bytes: number[]): ArrayBuffer => new Uint8Array(bytes).buffer;

export type AssertionOverrides = {
  authenticatorAttachment?: string | null;
  userHandle?: ArrayBuffer | null;
  clientExtensionResults?: Record<string, unknown>;
};

export function assertionCredential(overrides: AssertionOverrides = {}) {
  return {
    id: "cred-id",
    rawId: buffer([1, 2, 3]),
    type: "public-key",
    authenticatorAttachment: overrides.authenticatorAttachment ?? null,
    response: {
      clientDataJSON: buffer([4, 5, 6]),
      authenticatorData: buffer([7, 8, 9]),
      signature: buffer([10, 11, 12]),
      userHandle: overrides.userHandle ?? null,
    },
    getClientExtensionResults: () => overrides.clientExtensionResults ?? {},
  };
}

export type AttestationOverrides = {
  authenticatorAttachment?: string | null;
  transports?: string[] | null;
};

export function attestationCredential(overrides: AttestationOverrides = {}) {
  const { transports } = overrides;

  return {
    id: "cred-id",
    rawId: buffer([1, 2, 3]),
    type: "public-key",
    authenticatorAttachment: overrides.authenticatorAttachment ?? null,
    response: {
      clientDataJSON: buffer([4, 5, 6]),
      attestationObject: buffer([13, 14, 15]),
      ...(transports === null ? {} : { getTransports: () => transports ?? ["internal"] }),
    },
    getClientExtensionResults: () => ({}),
  };
}

/** The server's assertion options, as JSON-safe base64url the way Rails serialises them. */
export const REQUEST_OPTIONS = { challenge: "Y2hhbGxlbmdl" };

/** The server's creation options, as JSON-safe base64url the way Rails serialises them. */
export const CREATION_OPTIONS = {
  challenge: "Y2hhbGxlbmdl",
  rp: { name: "Umaxica", id: "example.test" },
  user: { id: "dXNlci1pZA", name: "someone@example.test", displayName: "Someone" },
  pubKeyCredParams: [{ type: "public-key", alg: -7 }],
};

/** Installs a `navigator.credentials` stub and answers its two mocked methods. */
export function stubCredentialsApi(): {
  get: Mock<CredentialsContainer["get"]>;
  create: Mock<CredentialsContainer["create"]>;
} {
  const get = vi.fn<CredentialsContainer["get"]>();
  const create = vi.fn<CredentialsContainer["create"]>();

  vi.stubGlobal("navigator", { credentials: { get, create } });
  // Only its presence is read (`passkeysSupported`), never its shape.
  vi.stubGlobal("PublicKeyCredential", function PublicKeyCredential() {});

  return { get, create };
}

/** An error the credential API raises, identified by its `name` the way the platform does. */
export function credentialError(name: string, message = ""): Error {
  const error = new Error(message);
  error.name = name;
  return error;
}
