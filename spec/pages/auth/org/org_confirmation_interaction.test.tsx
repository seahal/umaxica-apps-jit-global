import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { answerConfirmation } from "../../../support/confirmation";

// The operator screens keep their document submissions: the confirmation only decides whether the
// same POST (carrying `_method`) is replayed. jsdom performs no navigation, so `submit()` is spied
// on and stands in for it.
vi.mock("@/lib/csrf", () => ({ csrfToken: () => "csrf-token" }));

const deleteRequest = vi.fn();
const patchRequest = vi.fn();
vi.mock("@inertiajs/react", () => ({
  router: { delete: deleteRequest, patch: patchRequest },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData: vi.fn(),
    transform: vi.fn(),
    patch: patchRequest,
    processing: false,
    errors: {},
  }),
}));

vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: () => (
    <input
      type="hidden"
      name="cf-turnstile-response"
      value="turnstile-token"
    />
  ),
}));

const { default: OrgPasskeySettingsIndex } =
  await import("@/pages/base/org/identity/passkeys/index");
const { default: OrgPasskeySettingsShow } = await import("@/pages/base/org/identity/passkeys/show");
const { default: OrgSessionLimitPage } = await import("@/pages/auth/org/sign/in/sessions/show");

let container: HTMLDivElement;
let root: Root;

const submitted = vi.fn();

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

const submitForm = (index = 0) => {
  const form = container.querySelectorAll("form")[index];
  const event = new Event("submit", { bubbles: true, cancelable: true });
  act(() => {
    form?.dispatchEvent(event);
  });
  return event;
};

const clickButton = (label: string) => {
  const button = [...container.querySelectorAll("button")].find(
    (candidate) => candidate.textContent === label,
  )!;
  act(() => {
    button.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

beforeEach(() => {
  vi.spyOn(HTMLFormElement.prototype, "submit").mockImplementation(submitted);
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  submitted.mockClear();
  deleteRequest.mockClear();
  vi.restoreAllMocks();
});

describe("org passkey settings confirmation", () => {
  const indexProps = {
    title: "パスキー",
    description: "登録済みのパスキー。",
    new_link: { label: "追加", href: "/settings/passkeys/new" },
    back_link: { label: "もどる", href: "/settings" },
    remove_label: "削除",
    remove_confirm: "このパスキーを削除しますか？",
    empty_message: "登録がありません。",
    passkeys: [
      {
        public_id: "pk_1",
        description: "ノートPC",
        created_at: null,
        last_used_at: null,
        show_href: "/settings/passkeys/pk_1",
        destroy_action: "/settings/passkeys/pk_1",
      },
    ],
  };

  it("explains an empty inventory", () => {
    mount(
      <OrgPasskeySettingsIndex
        {...indexProps}
        passkeys={[]}
      />,
    );

    expect(container.textContent).toContain("登録がありません。");
  });

  it("holds the deletion back until the operator accepts", () => {
    mount(<OrgPasskeySettingsIndex {...indexProps} />);

    clickButton("削除");
    expect(document.querySelector("[role='dialog']")?.textContent).toContain(
      "このパスキーを削除しますか？",
    );

    answerConfirmation(false);
    expect(submitted).not.toHaveBeenCalled();

    clickButton("削除");
    answerConfirmation(true);
    expect(deleteRequest).toHaveBeenCalledWith("/settings/passkeys/pk_1");
  });

  it("keeps the DELETE the show screen carries behind the same confirmation", () => {
    mount(
      <OrgPasskeySettingsShow
        title="ノートPC"
        description="登録済みのパスキー。"
        back_link={{ label: "もどる", href: "/settings/passkeys" }}
        passkey={{
          public_id: "pk_1",
          description: "ノートPC",
          created_at: "2026-01-01",
          last_used_at: null,
        }}
        form={{
          action: "/settings/passkeys/pk_1",
          description: "ノートPC",
          label: "名前",
          submit_label: "保存",
        }}
        destroy={{
          action: "/settings/passkeys/pk_1",
          label: "削除",
          confirm: "このパスキーを削除しますか？",
        }}
        error={null}
      />,
    );

    clickButton("削除");
    answerConfirmation(false);
    expect(deleteRequest).not.toHaveBeenCalled();

    clickButton("削除");
    answerConfirmation(true);
    expect(deleteRequest).toHaveBeenCalledWith("/settings/passkeys/pk_1");
  });
});

describe("org session limit confirmation", () => {
  const props = {
    title: "セッション上限",
    heading: "セッション上限に達しました",
    description: "いずれかのセッションを解除してください。",
    form_action: "/sign/in/session",
    active_sessions_heading: "有効なセッション",
    session_label: "セッション",
    created_at_label: "作成",
    last_used_label: "最終使用",
    no_sessions: "セッションがありません。",
    submit_label: "解除する",
    cancel_logout_label: "キャンセルしてログアウト",
    cancel_logout_confirm: "キャンセルしますか？ログアウトされます。",
    sessions: [
      {
        ref: "signed-ref",
        digest: "abcd",
        created_at: "2026-01-01",
        last_used_at: "2026-01-02",
      },
      {
        ref: "signed-ref-2",
        digest: "efgh",
        created_at: "2026-01-01",
        last_used_at: null,
      },
    ],
  };

  it("cancels the ceremony only once the operator accepts", () => {
    mount(<OrgSessionLimitPage {...props} />);

    // The first form is the revocation, which carries no confirmation.
    expect(submitForm(0).defaultPrevented).toBe(false);

    expect(submitForm(1).defaultPrevented).toBe(true);
    answerConfirmation(false);
    expect(submitted).not.toHaveBeenCalled();

    submitForm(1);
    answerConfirmation(true);
    expect(submitted).toHaveBeenCalledTimes(1);
  });

  // Authentication already succeeded, so the page carries no link back into the sign-in form.
  it("renders no navigation link, leaving the cancellation as the only exit", () => {
    mount(<OrgSessionLimitPage {...props} />);

    expect(container.querySelectorAll("a")).toHaveLength(0);
  });

  it("shows the empty copy when the server named no sessions", () => {
    mount(
      <OrgSessionLimitPage
        {...props}
        sessions={[]}
      />,
    );

    expect(container.textContent).toContain("セッションがありません。");
  });
});
