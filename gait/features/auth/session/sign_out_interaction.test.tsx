import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import { present } from "../../../support/present";

// Sign-out is destructive, so these tests mount the components and inspect the forms the browser
// would submit. They are document submissions, not Inertia visits: the confirmation answers with a
// cross-origin 303, so the form itself must carry the verb, the CSRF token.
const { default: SignOutConfirmation } =
  await import("@/features/auth/session/SignOutConfirmation");
const { default: SignOutUnavailable } = await import("@/features/auth/session/SignOutUnavailable");

let container: HTMLDivElement;
let root: Root;
let csrfMeta: HTMLMetaElement;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

// Every field here is a hidden text input, so each entry is a string rather than a File.
const fields = (form: HTMLFormElement) => Object.fromEntries(new FormData(form).entries());

beforeEach(() => {
  csrfMeta = document.createElement("meta");
  csrfMeta.name = "csrf-token";
  csrfMeta.content = "csrf-value";
  document.head.append(csrfMeta);
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  csrfMeta.remove();
});

const confirmationProps = {
  title: "ログアウトしますか？",
  heading: "ログアウトしますか？",
  active_context: true,
  confirm_description: "一度ログアウトすると、再度ログインが必要になります。",
  already_signed_out: "すでにサインアウトしています。",
  submit_label: "ログアウトします",
  form: { action: "/sign/out?ri=jp" },
  cancel: { label: "キャンセル", action: "/sign/out?ri=jp" },
  home_link: { label: "ホームへ戻る", href: "/?ri=jp" },
};

describe("SignOutConfirmation interaction", () => {
  it("confirms with a document POST carrying the CSRF token", () => {
    mount(<SignOutConfirmation {...confirmationProps} />);

    const forms = [...container.querySelectorAll("form")];

    expect(forms).toHaveLength(2);

    const confirmation = present(forms[0], "the sign-out form");

    expect(confirmation.getAttribute("action")).toBe("/sign/out?ri=jp");
    expect(confirmation.getAttribute("method")).toBe("post");
    expect(fields(confirmation)).toEqual({
      authenticity_token: "csrf-value",
    });
  });

  it("cancels with a document POST overridden to DELETE", () => {
    mount(<SignOutConfirmation {...confirmationProps} />);

    const cancellation = present(container.querySelectorAll("form")[1], "the cancel form");

    expect(cancellation.getAttribute("action")).toBe("/sign/out?ri=jp");
    expect(cancellation.getAttribute("method")).toBe("post");
    expect(fields(cancellation)).toEqual({ authenticity_token: "csrf-value", _method: "delete" });
  });


});

describe("SignOutUnavailable interaction", () => {
  it("retries the ceremony with a document POST carrying the token", () => {
    mount(
      <SignOutUnavailable
        title="ログアウトできません"
        heading="ログアウトできません"
        description="もう一度お試しください。"
        retry={{ label: "再試行", action: "/sign/out?ri=jp" }}
        home_link={{ label: "ホームへ戻る", href: "/?ri=jp" }}
      />,
    );

    const retry = present(container.querySelectorAll("form")[0], "the retry form");

    expect(retry.getAttribute("action")).toBe("/sign/out?ri=jp");
    expect(retry.getAttribute("method")).toBe("post");
    expect(fields(retry)).toEqual({ authenticity_token: "csrf-value" });
  });
});
