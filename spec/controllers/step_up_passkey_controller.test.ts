// The step-up passkey form on the surfaces that do not boot React.
//
// The ceremony itself -- normalising the server's options, calling the credential API and encoding
// the assertion -- lives in `@/features/auth/passkeys/webauthn` and is covered with the React
// screens. What belongs here is what the controller decides: the preconditions it refuses on, the
// fields it fills, that it submits the form, and which message each failure shows.
import { beforeEach, describe, expect, it, vi } from "vitest";

import StepUpPasskeyController from "@/controllers/step_up_passkey_controller";

import { mountController } from "../support/stimulus";
import {
  REQUEST_OPTIONS,
  assertionCredential,
  credentialError,
  stubCredentialsApi,
} from "../support/webauthn";

const markup = (options: unknown = REQUEST_OPTIONS, challengeId = "challenge-123") => `
  <form data-controller="step-up-passkey"
        data-step-up-passkey-options-value='${JSON.stringify(options)}'
        data-step-up-passkey-challenge-id-value="${challengeId}">
    <input type="hidden" data-step-up-passkey-target="challengeId">
    <input type="hidden" data-step-up-passkey-target="credentialJson">
    <p data-step-up-passkey-target="error" class="hidden"></p>
    <p data-step-up-passkey-target="status" class="hidden"></p>
    <button type="submit" data-action="step-up-passkey#authenticate">Continue</button>
  </form>
`;

const mount = (html = markup()) =>
  mountController<StepUpPasskeyController>("step-up-passkey", StepUpPasskeyController, html);

let credentials: ReturnType<typeof stubCredentialsApi>;
let submitted: number;

beforeEach(() => {
  credentials = stubCredentialsApi();
  submitted = 0;
  // jsdom does not implement form submission; counting the call is what the assertion needs.
  HTMLFormElement.prototype.requestSubmit = vi.fn(() => {
    submitted += 1;
  });
});

describe("StepUpPasskeyController", () => {
  describe("authenticate", () => {
    it("fills the hidden fields and submits the form", async () => {
      credentials.get.mockResolvedValue(assertionCredential());
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      const credentialJson = element.querySelector<HTMLInputElement>(
        "[data-step-up-passkey-target='credentialJson']",
      );
      const challengeId = element.querySelector<HTMLInputElement>(
        "[data-step-up-passkey-target='challengeId']",
      );

      expect(JSON.parse(String(credentialJson?.value))).toMatchObject({ id: "cred-id" });
      expect(challengeId?.value).toBe("challenge-123");
      expect(submitted).toBe(1);
    });

    it("carries the user handle and the attachment the authenticator reported", async () => {
      credentials.get.mockResolvedValue(
        assertionCredential({
          authenticatorAttachment: "platform",
          userHandle: new Uint8Array([13, 14, 15]).buffer,
        }),
      );
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      const value = element.querySelector<HTMLInputElement>(
        "[data-step-up-passkey-target='credentialJson']",
      )?.value;
      const parsed: unknown = JSON.parse(String(value));

      expect(parsed).toMatchObject({ authenticatorAttachment: "platform" });
      expect(JSON.stringify(parsed)).toContain("userHandle");
    });

    it("refuses when the browser does not support passkeys", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("このブラウザはPasskeyに対応していません");
      expect(credentials.get).not.toHaveBeenCalled();
    });

    it("refuses when the controller is not inside a form", async () => {
      const { controller, element } = await mount(`
        <div data-controller="step-up-passkey"
             data-step-up-passkey-options-value='${JSON.stringify(REQUEST_OPTIONS)}'
             data-step-up-passkey-challenge-id-value="challenge-123">
          <input type="hidden" data-step-up-passkey-target="challengeId">
          <input type="hidden" data-step-up-passkey-target="credentialJson">
          <p data-step-up-passkey-target="error" class="hidden"></p>
          <p data-step-up-passkey-target="status" class="hidden"></p>
        </div>
      `);

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("認証中にエラーが発生しました");
    });

    it("refuses when the server sent no options", async () => {
      const { controller, element } = await mount(markup(REQUEST_OPTIONS, ""));

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("認証オプションの取得に失敗しました");
    });

    it("reports a cancelled ceremony in the visitor's terms", async () => {
      credentials.get.mockRejectedValue(credentialError("NotAllowedError", "Cancelled"));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("認証がキャンセルされました");
    });

    it("reports a security failure in the visitor's terms", async () => {
      credentials.get.mockRejectedValue(credentialError("SecurityError", "Security issue"));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("セキュリティエラーが発生しました");
    });

    it("shows the message of a failure it has no copy for", async () => {
      credentials.get.mockRejectedValue(credentialError("GenericError", "Something went wrong"));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("Something went wrong");
    });

    it("falls back to its own copy when the failure carries no message", async () => {
      credentials.get.mockRejectedValue(credentialError("GenericError"));
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("認証中にエラーが発生しました");
    });

    it("falls back to its own copy when the failure is not an Error", async () => {
      credentials.get.mockRejectedValue("not-an-error");
      const { controller, element } = await mount();

      await controller.authenticate(new Event("click"));

      expect(errorText(element)).toBe("認証中にエラーが発生しました");
    });
  });

  describe("messages", () => {
    it("hides the status when it shows an error", async () => {
      const { controller, element } = await mount();

      controller.showStatus("working");
      controller.showError("broken");

      expect(statusElement(element)?.classList.contains("hidden")).toBe(true);
      expect(errorElement(element)?.classList.contains("hidden")).toBe(false);
    });

    it("clears both messages", async () => {
      const { controller, element } = await mount();

      controller.showError("broken");
      controller.clearMessages();

      expect(errorText(element)).toBe("");
      expect(errorElement(element)?.classList.contains("hidden")).toBe(true);
      expect(statusElement(element)?.classList.contains("hidden")).toBe(true);
    });

    it("does nothing when the markup carries no message elements", async () => {
      const bare = `
        <form data-controller="step-up-passkey"
              data-step-up-passkey-options-value='${JSON.stringify(REQUEST_OPTIONS)}'
              data-step-up-passkey-challenge-id-value="challenge-123">
          <input type="hidden" data-step-up-passkey-target="challengeId">
          <input type="hidden" data-step-up-passkey-target="credentialJson">
        </form>
      `;
      const { controller } = await mount(bare);

      expect(() => {
        controller.showError("broken");
        controller.showStatus("working");
        controller.clearMessages();
      }).not.toThrow();
    });
  });
});

function errorElement(element: HTMLElement) {
  return element.querySelector("[data-step-up-passkey-target='error']");
}

function statusElement(element: HTMLElement) {
  return element.querySelector("[data-step-up-passkey-target='status']");
}

function errorText(element: HTMLElement): string | null {
  return errorElement(element)?.textContent ?? null;
}
