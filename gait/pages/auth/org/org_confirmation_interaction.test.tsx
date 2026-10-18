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
