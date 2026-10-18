// The ceremony's error vocabulary. Each branch answers a different string to the visitor, so a
// wrong one is a wrong instruction mid-authentication rather than a cosmetic slip.
import { describe, expect, it } from "vitest";

import {
  PASSKEY_MESSAGES,
  authenticationErrorMessage,
  registrationErrorMessage,
} from "@/features/auth/passkeys/messages";

const named = (name: string, message = ""): Error => {
  const error = new Error(message);
  error.name = name;
  return error;
};

describe("authenticationErrorMessage", () => {
  it("reports a cancelled ceremony rather than a failure", () => {
    expect(authenticationErrorMessage(named("NotAllowedError"))).toBe(PASSKEY_MESSAGES.cancelled);
    expect(authenticationErrorMessage(new DOMException("", "NotAllowedError"))).toBe(
      PASSKEY_MESSAGES.cancelled,
    );
  });

  it("reports a security error under its own name", () => {
    expect(authenticationErrorMessage(named("SecurityError"))).toBe(PASSKEY_MESSAGES.securityError);
  });

  it("passes through the message an error carries", () => {
    expect(authenticationErrorMessage(new Error("サーバーが応答しません"))).toBe(
      "サーバーが応答しません",
    );
  });

  it("falls back to the generic message for an error with none", () => {
    expect(authenticationErrorMessage(new Error(""))).toBe(PASSKEY_MESSAGES.authenticationError);
  });

  it("falls back to the generic message for something that is not an error", () => {
    expect(authenticationErrorMessage("boom")).toBe(PASSKEY_MESSAGES.authenticationError);
    expect(authenticationErrorMessage(null)).toBe(PASSKEY_MESSAGES.authenticationError);
  });
});

describe("registrationErrorMessage", () => {
  it("reports a cancelled ceremony rather than a failure", () => {
    expect(registrationErrorMessage(named("NotAllowedError"))).toBe(PASSKEY_MESSAGES.cancelled);
  });

  it("names an authenticator that already holds this passkey", () => {
    expect(registrationErrorMessage(named("InvalidStateError"))).toBe(
      PASSKEY_MESSAGES.alreadyRegistered,
    );
    expect(registrationErrorMessage(new DOMException("", "InvalidStateError"))).toBe(
      PASSKEY_MESSAGES.alreadyRegistered,
    );
  });

  it("passes through the message an error carries", () => {
    expect(registrationErrorMessage(new Error("登録は拒否されました"))).toBe(
      "登録は拒否されました",
    );
  });

  it("falls back to the generic message for an error with none", () => {
    expect(registrationErrorMessage(new Error(""))).toBe(PASSKEY_MESSAGES.registrationError);
  });

  it("falls back to the generic message for something that is not an error", () => {
    expect(registrationErrorMessage({ name: "NotAllowedError" })).toBe(
      PASSKEY_MESSAGES.registrationError,
    );
  });
});
