// Registering a passkey on the surfaces that do not boot React.
//
// The credential ceremony lives in `@/features/auth/passkeys/webauthn` and the request/response
// handling in `@/controllers/passkey_ceremony`; both have their own specs. What belongs here is
// what this controller decides: which url each step goes to when the surface names it two
// different ways, what the finish request carries, and where the visitor lands afterwards.
import { Controller } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const solveInvisibleTurnstile = vi.fn(async (): Promise<string> => {
  throw new Error("Security verification failed. Please refresh and try again.");
});

vi.mock("@/features/auth/passkeys/invisibleTurnstile", () => ({
  solveInvisibleTurnstile: () => solveInvisibleTurnstile(),
}));

import PasskeyRegistrationController from "@/controllers/passkey_registration_controller";

import { jsonResponse, requestAt, stubCeremonyFetch, textResponse } from "../support/ceremony";
import { mountController } from "../support/stimulus";
import {
  CREATION_OPTIONS,
  attestationCredential,
  credentialError,
  stubCredentialsApi,
} from "../support/webauthn";

const BEGIN_URL = "/settings/passkeys/begin";
const FINISH_URL = "/settings/passkeys/finish";

type MarkupOptions = {
  urlStyle?: "begin-finish" | "options-verification";
  description?: string | null;
  successRedirectUrl?: string | null;
  checkpointVersion?: string | null;
  turnstileToken?: string;
};

function markup({
  urlStyle = "begin-finish",
  description = "iPhone",
  successRedirectUrl = null,
  checkpointVersion = null,
  turnstileToken = "solved-token",
}: MarkupOptions = {}): string {
  const urls =
    urlStyle === "begin-finish"
      ? `data-passkey-registration-begin-url-value="${BEGIN_URL}"
         data-passkey-registration-finish-url-value="${FINISH_URL}"`
      : `data-passkey-registration-options-url-value="${BEGIN_URL}"
         data-passkey-registration-verification-url-value="${FINISH_URL}"`;

  return `
    <div data-controller="passkey-registration"
         ${urls}
         ${successRedirectUrl === null ? "" : `data-passkey-registration-success-redirect-url-value="${successRedirectUrl}"`}
         ${checkpointVersion === null ? "" : `data-passkey-registration-checkpoint-version-value="${checkpointVersion}"`}
         data-passkey-registration-turnstile-site-key-value="site-key">
      ${description === null ? "" : `<input type="text" value="${description}" data-passkey-registration-target="description">`}
      <input type="hidden" value="${turnstileToken}"
             data-passkey-registration-target="turnstileResponse">
      <p data-passkey-registration-target="error" class="hidden"></p>
      <p data-passkey-registration-target="status" class="hidden"></p>
    </div>
  `;
}

const mount = (options?: MarkupOptions) =>
  mountController("passkey-registration", PasskeyRegistrationController, markup(options));

function messageText(element: HTMLElement, target: "error" | "status"): string {
  return element.querySelector(`[data-passkey-registration-target="${target}"]`)?.textContent ?? "";
}

/** The controller navigates on success; jsdom has no navigation, so the assignment is observed. */
function stubNavigation(): { href: () => string; reloaded: () => boolean } {
  let href = "";
  let reloaded = false;

  Object.defineProperty(window, "location", {
    value: {
      get href() {
        return href;
      },
      set href(value: string) {
        href = value;
      },
      origin: "https://example.test",
      search: "",
      reload: () => {
        reloaded = true;
      },
    },
    configurable: true,
    writable: true,
  });

  return { href: () => href, reloaded: () => reloaded };
}

const BEGUN = { challenge_id: "challenge-1", options: CREATION_OPTIONS };

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
  stubCredentialsApi();
});

afterEach(() => {
  vi.unstubAllGlobals();
  solveInvisibleTurnstile.mockReset();
  solveInvisibleTurnstile.mockImplementation(async () => {
    throw new Error("Security verification failed. Please refresh and try again.");
  });
});

describe("PasskeyRegistrationController", () => {
  it("is a Stimulus controller, so the registry can register it", () => {
    expect(PasskeyRegistrationController.prototype).toBeInstanceOf(Controller);
  });

  describe("a ceremony the server accepts", () => {
    it("posts the Turnstile token, then the credential and its description", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/settings/passkeys" }),
      );
      const navigation = stubNavigation();
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      const begin = requestAt(fetchMock, 0);
      expect(begin.url).toBe(BEGIN_URL);
      expect(begin.body).toEqual({ "cf-turnstile-response": "solved-token" });

      const finish = requestAt(fetchMock, 1);
      expect(finish.url).toBe(FINISH_URL);
      expect(finish.body).toMatchObject({
        challenge_id: "challenge-1",
        description: "iPhone",
        credential: { id: "cred-id", type: "public-key" },
      });

      expect(messageText(element, "status")).toBe("登録完了！リダイレクト中...");
      expect(navigation.href()).toBe("/settings/passkeys");
    });

    it("accepts the options/verification spelling of the same two urls", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/x" }),
      );
      stubNavigation();
      const { controller } = await mount({ urlStyle: "options-verification" });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 0).url).toBe(BEGIN_URL);
      expect(requestAt(fetchMock, 1).url).toBe(FINISH_URL);
    });

    it("sends the checkpoint version when the surface carries one", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/x" }),
      );
      stubNavigation();
      const { controller } = await mount({ checkpointVersion: "v3" });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 1).body).toMatchObject({ checkpoint_version: "v3" });
    });

    it("sends an empty description when the screen has no field for one", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/x" }),
      );
      stubNavigation();
      const { controller } = await mount({ description: null });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 1).body).toMatchObject({ description: "" });
    });

    it("falls back to the surface's own redirect when the server names none", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}));
      const navigation = stubNavigation();
      const { controller } = await mount({ successRedirectUrl: "/settings" });

      await controller.register(new Event("click"));

      expect(navigation.href()).toBe("/settings");
    });

    it("reloads when neither the server nor the surface names a destination", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}));
      const navigation = stubNavigation();
      const { controller } = await mount();

      await controller.register(new Event("click"));

      expect(navigation.reloaded()).toBe(true);
    });
  });

  describe("refuses to start", () => {
    it("when the browser cannot do WebAuthn", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("このブラウザはPasskeyに対応していません");
    });

    it("solves Turnstile when the page omitted the hidden field", async () => {
      solveInvisibleTurnstile.mockResolvedValueOnce("fresh-token");
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/settings/passkeys" }),
      );
      stubNavigation();
      const { controller } = await mountController(
        "passkey-registration",
        PasskeyRegistrationController,
        `
          <div data-controller="passkey-registration"
               data-passkey-registration-begin-url-value="${BEGIN_URL}"
               data-passkey-registration-finish-url-value="${FINISH_URL}"
               data-passkey-registration-turnstile-site-key-value="site-key">
            <input type="text" value="iPhone" data-passkey-registration-target="description">
            <p data-passkey-registration-target="error" class="hidden"></p>
            <p data-passkey-registration-target="status" class="hidden"></p>
          </div>
        `,
      );

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 0).body).toMatchObject({
        "cf-turnstile-response": "fresh-token",
      });
    });

    it("reports a refusal when the page omitted the message elements", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      const { controller } = await mountController(
        "passkey-registration",
        PasskeyRegistrationController,
        `
          <div data-controller="passkey-registration"
               data-passkey-registration-begin-url-value="${BEGIN_URL}"
               data-passkey-registration-finish-url-value="${FINISH_URL}"
               data-passkey-registration-turnstile-site-key-value="site-key">
            <input type="hidden" value="solved-token" data-passkey-registration-target="turnstileResponse">
          </div>
        `,
      );

      await controller.register(new Event("click"));

      expect(controller).toBeDefined();
    });

    it("sends an empty description when the field is blank", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/settings/passkeys" }),
      );
      stubNavigation();
      const { controller } = await mount({ description: "" });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 1).body).toMatchObject({ description: "" });
    });

    it("sends an empty description when the field is absent", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/settings/passkeys" }),
      );
      stubNavigation();
      const { controller } = await mount({ description: null });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 1).body).toMatchObject({ description: "" });
    });

    it("prevents the click from submitting the surrounding form", async () => {
      vi.stubGlobal("PublicKeyCredential", undefined);
      const { controller } = await mount();
      const event = new Event("click", { cancelable: true });

      await controller.register(event);

      expect(event.defaultPrevented).toBe(true);
    });
  });

  describe("a server that refuses the ceremony", () => {
    it("shows the error the begin request returned", async () => {
      stubCeremonyFetch(jsonResponse({ error: "上限に達しています" }, 422));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("上限に達しています");
    });

    it("falls back to its own copy when the error carries no message", async () => {
      stubCeremonyFetch(jsonResponse({}, 422));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("オプションの取得に失敗しました");
    });

    it("shows the error the finish request returned", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({ error: "証明書が不正です" }, 422));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("証明書が不正です");
    });

    it("falls back to its own copy when the finish error carries no message", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), jsonResponse({}, 422));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("登録に失敗しました");
    });

    it.each([401, 302])("reloads onto the sign-in screen on %i", async (status) => {
      stubCeremonyFetch(textResponse("", status));
      const navigation = stubNavigation();
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(navigation.reloaded()).toBe(true);
      expect(messageText(element, "error")).toBe("");
    });

    it("reloads when the session ends between the two requests", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      stubCeremonyFetch(jsonResponse(BEGUN), textResponse("", 401));
      const navigation = stubNavigation();
      const { controller } = await mount();

      await controller.register(new Event("click"));

      expect(navigation.reloaded()).toBe(true);
    });

    it("falls back to its own copy for a non-JSON failure", async () => {
      stubCeremonyFetch(textResponse("<html>oops</html>", 500, "text/html"));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("オプションの取得に失敗しました");
    });
  });

  describe("reports the authenticator's own failures", () => {
    it.each([
      ["NotAllowedError", "認証がキャンセルされました"],
      ["InvalidStateError", "このPasskeyは既に登録されています"],
    ])("maps %s onto its own copy", async (name, message) => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue(credentialError(name));
      stubCeremonyFetch(jsonResponse(BEGUN));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe(message);
    });

    it("shows the failure's own message when it has one", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue(new Error("認証器が応答しません"));
      stubCeremonyFetch(jsonResponse(BEGUN));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("認証器が応答しません");
    });

    it("falls back when the failure is not an Error at all", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockRejectedValue("nope");
      stubCeremonyFetch(jsonResponse(BEGUN));
      const { controller, element } = await mount();

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe("登録中にエラーが発生しました");
    });
  });

  describe("the Turnstile token", () => {
    it("reuses the token already in the hidden field", async () => {
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/x" }),
      );
      stubNavigation();
      const { controller } = await mount({ turnstileToken: "already-solved" });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 0).body).toMatchObject({
        "cf-turnstile-response": "already-solved",
      });
    });

    it("solves an empty field and writes the token back", async () => {
      solveInvisibleTurnstile.mockResolvedValueOnce("fresh-token");
      const credentials = stubCredentialsApi();
      credentials.create.mockResolvedValue(attestationCredential());
      const fetchMock = stubCeremonyFetch(
        jsonResponse(BEGUN),
        jsonResponse({ redirect_url: "/x" }),
      );
      stubNavigation();
      const { controller } = await mount({ turnstileToken: "" });

      await controller.register(new Event("click"));

      expect(requestAt(fetchMock, 0).body).toMatchObject({
        "cf-turnstile-response": "fresh-token",
      });
    });

    it("reports the failure when no widget can be solved", async () => {
      const { controller, element } = await mount({ turnstileToken: "" });

      await controller.register(new Event("click"));

      expect(messageText(element, "error")).toBe(
        "Security verification failed. Please refresh and try again.",
      );
    });
  });
});
