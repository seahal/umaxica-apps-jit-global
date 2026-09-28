import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// The passkey step-up screen is the one verification page that runs a ceremony in the browser.
// These tests mount it and click the button, so the branches the Stimulus controller used to own -
// unsupported browser, missing challenge, cancelled assertion, success - are exercised here.
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
  form: {
    action: "/verification/passkey?ri=jp",
    csrf_token: "csrf-token",
    scope: "settings_passkey",
    pt: "pt-value",
    challenge_id: "challenge-1",
    request_options: { challenge: "abc" },
    submit_label: "パスキーで認証",
  },
  back: { label: "戻る", href: "/verification?ri=jp" },
};

let container: HTMLDivElement;
let root: Root;
const requestSubmit = vi.fn();
// What the field held at the moment the form was submitted is the invariant that matters: the
// assertion must be in the DOM before the document submission leaves, not one render later.
let submittedCredential = "";

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

const credentialField = () =>
  container.querySelector<HTMLInputElement>('input[name="verification[credential_json]"]');

beforeEach(() => {
  vi.spyOn(HTMLFormElement.prototype, "requestSubmit").mockImplementation(() => {
    submittedCredential = credentialField()?.value ?? "";
    requestSubmit();
  });
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  vi.restoreAllMocks();
  getAssertion.mockReset();
  passkeysSupported.mockReset();
  requestSubmit.mockClear();
  submittedCredential = "";
});

describe("PasskeyVerification interaction", () => {
  it("submits the serialized assertion when the authenticator answers", async () => {
    passkeysSupported.mockReturnValue(true);
    getAssertion.mockResolvedValue(SERIALIZED_ASSERTION);
    mount(<PasskeyVerification {...props} />);

    await click();

    expect(getAssertion).toHaveBeenCalledWith({ challenge: "abc" });
    expect(submittedCredential).toBe(JSON.stringify(SERIALIZED_ASSERTION));
    expect(requestSubmit).toHaveBeenCalled();
  });

  it("refuses to start when the browser has no WebAuthn support", async () => {
    passkeysSupported.mockReturnValue(false);
    mount(<PasskeyVerification {...props} />);

    await click();

    expect(getAssertion).not.toHaveBeenCalled();
    expect(requestSubmit).not.toHaveBeenCalled();
    expect(container.textContent).toContain("このブラウザはPasskeyに対応していません");
  });

  it("refuses to start when the server issued no challenge", async () => {
    passkeysSupported.mockReturnValue(true);
    mount(
      <PasskeyVerification
        {...props}
        form={{ ...props.form, challenge_id: "", request_options: null }}
      />,
    );

    await click();

    expect(getAssertion).not.toHaveBeenCalled();
    expect(container.textContent).toContain("認証オプションの取得に失敗しました");
  });

  it("reports a cancelled ceremony without submitting", async () => {
    passkeysSupported.mockReturnValue(true);
    getAssertion.mockRejectedValue(new DOMException("cancelled", "NotAllowedError"));
    mount(<PasskeyVerification {...props} />);

    await click();

    expect(requestSubmit).not.toHaveBeenCalled();
    expect(container.textContent).toContain("認証がキャンセルされました");
  });
});
