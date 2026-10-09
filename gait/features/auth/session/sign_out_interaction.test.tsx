import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

// Sign-out is destructive, so these tests mount the components and submit them for real to prove
// the verbs never degrade to a GET.
const post = vi.fn();
const deleteRequest = vi.fn();
const transform = vi.fn();

vi.mock("@inertiajs/react", () => ({
  useForm: () => ({
    processing: false,
    post,
    delete: deleteRequest,
    transform: () => ({ post, delete: deleteRequest, patch: post, processing: false }),
  }),
}));

const { default: SignOutConfirmation } =
  await import("@/features/auth/session/SignOutConfirmation");
const { default: SignOutUnavailable } = await import("@/features/auth/session/SignOutUnavailable");

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

const submit = (form: HTMLFormElement) => {
  act(() => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
};

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  post.mockClear();
  deleteRequest.mockClear();
  transform.mockClear();
});

const confirmationProps = {
  title: "ログアウトしますか？",
  heading: "ログアウトしますか？",
  active_context: true,
  confirm_description: "一度ログアウトすると、再度ログインが必要になります。",
  already_signed_out: "すでにサインアウトしています。",
  submit_label: "ログアウトします",
  form: { action: "/sign/out?ri=jp", logout_challenge: "challenge-value" },
  cancel: { label: "キャンセル", action: "/sign/out?ri=jp" },
  home_link: { label: "ホームへ戻る", href: "/?ri=jp" },
};

describe("SignOutConfirmation interaction", () => {
  it("confirms with a POST and cancels with a DELETE", () => {
    mount(<SignOutConfirmation {...confirmationProps} />);

    const forms = [...container.querySelectorAll("form")];

    expect(forms).toHaveLength(2);

    submit(present(forms[0], "the sign-out form"));

    expect(post).toHaveBeenCalledWith("/sign/out?ri=jp");
    expect(deleteRequest).not.toHaveBeenCalled();

    submit(present(forms[1], "the cancel form"));

    expect(deleteRequest).toHaveBeenCalledWith("/sign/out?ri=jp");
  });

  it("carries no challenge when the ceremony did not start with one", () => {
    mount(
      <SignOutConfirmation
        {...confirmationProps}
        form={{ action: "/sign/out?ri=jp", logout_challenge: null }}
      />,
    );

    submit(present(container.querySelectorAll("form")[0], "the sign-out form"));

    expect(post).toHaveBeenCalledWith("/sign/out?ri=jp");
  });
});

describe("SignOutUnavailable interaction", () => {
  it("retries the ceremony with a POST", () => {
    mount(
      <SignOutUnavailable
        title="ログアウトできません"
        heading="ログアウトできません"
        description="もう一度お試しください。"
        retry={{ label: "再試行", action: "/sign/out?ri=jp" }}
        home_link={{ label: "ホームへ戻る", href: "/?ri=jp" }}
      />,
    );

    submit(present(container.querySelectorAll("form")[0], "the sign-out form"));

    expect(post).toHaveBeenCalledWith("/sign/out?ri=jp");
  });
});
import { present } from "../../../support/present";
