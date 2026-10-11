import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { answerConfirmation } from "../../../../support/confirmation";
import { present } from "../../../../support/present";

// These tests mount the screens and dispatch real DOM events, which is the only way to reach the
// submit and confirm branches: the destructive actions must keep their verb and their confirmation.
const patch = vi.fn();
const post = vi.fn();
const deleteRequest = vi.fn();
const transform = vi.fn<(callback: (data: Record<string, string>) => unknown) => void>();
const setData = vi.fn();

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: deleteRequest, patch, post },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData,
    transform,
    patch,
    post,
    processing: false,
    errors: {},
  }),
  usePage: () => ({ props: {} }),
}));

const { default: SocialLinkManage } = await import("@/features/auth/settings/SocialLinkManage");
const { default: PasskeysIndex } = await import("@/pages/auth/app/settings/passkeys/index");
const { default: PasskeysEdit } = await import("@/pages/auth/app/settings/passkeys/edit");
const { default: TotpsNew } = await import("@/pages/auth/app/settings/totps/new");
const { default: TotpsEdit } = await import("@/pages/auth/app/settings/totps/edit");

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

const submitForm = () => {
  const form = container.querySelector<HTMLFormElement>("form")!;
  act(() => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
};

// React tracks the last value it wrote to a controlled input, so a plain assignment is ignored.
// Writing through the native setter is what makes the change event reach the handler.
const typeInto = (input: HTMLInputElement, value: string) => {
  const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
  act(() => {
    descriptor?.set?.call(input, value);
    input.dispatchEvent(new Event("input", { bubbles: true }));
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

// The confirmation is a rendered dialog now: its cancel button is first and its confirm button
// second, so answering it is a click rather than a stubbed `window.confirm`.

const turnstile = {
  site_key: "site-key",
  mode: "execute" as const,
  action: null,
  cdata: null,
};

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  vi.unstubAllGlobals();
  patch.mockClear();
  post.mockClear();
  deleteRequest.mockClear();
  transform.mockClear();
  setData.mockClear();
});

describe("SocialLinkManage interaction", () => {
  const props = {
    title: "Apple",
    heading: "Apple",
    description: "Appleアカウントとの連携",
    back_link: { label: "もどる", href: "/settings" },
    connect: null,
    turnstile,
  };

  it("disconnects with a DELETE carrying the challenge field", () => {
    mount(
      <SocialLinkManage
        {...props}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: true,
          blocked_notice: null,
        }}
      />,
    );

    submitForm();

    expect(deleteRequest).toHaveBeenCalledWith("/settings/apple?ri=jp", {
      data: { "cf-turnstile-response": "" },
    });
  });

  it("submits nothing while unlinking is not allowed", () => {
    mount(
      <SocialLinkManage
        {...props}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: false,
          blocked_notice: "他のログイン方法がありません",
        }}
      />,
    );

    submitForm();

    expect(deleteRequest).not.toHaveBeenCalled();
  });
});

describe("passkey settings interaction", () => {
  const indexProps = {
    title: "Passkeys",
    back_link: { label: "もどる", href: "/settings" },
    new_link: { label: "追加", href: "/settings/passkeys/new?ri=jp" },
    columns: {
      description: "名前",
      created_at: "作成日",
      last_used_at: "最終利用",
      actions: "操作",
    },
    empty_message: "登録がありません",
    edit_label: "編集",
    destroy_label: "削除",
    destroy_confirm: "削除しますか",
    turnstile,
    passkeys: [
      {
        public_id: "pk_1",
        description: "MacBook",
        created_at: "2026/01/01",
        last_used_at: "-",
        edit_href: "/settings/passkeys/pk_1/edit?ri=jp",
        destroy_href: "/settings/passkeys/pk_1?ri=jp",
      },
    ],
  };

  it("deletes a row once the confirmation is accepted", () => {
    mount(<PasskeysIndex {...indexProps} />);

    clickButton("削除");
    answerConfirmation(true);

    expect(deleteRequest).toHaveBeenCalledWith("/settings/passkeys/pk_1?ri=jp", {
      data: { "cf-turnstile-response": "" },
    });
  });

  it("keeps the row when the confirmation is declined", () => {
    mount(<PasskeysIndex {...indexProps} />);

    clickButton("削除");
    answerConfirmation(false);

    expect(deleteRequest).not.toHaveBeenCalled();
  });

  const editProps = {
    title: "Passkeyの編集",
    description: "名前を変更します",
    back_link: { label: "もどる", href: "/settings/passkeys?ri=jp" },
    form: {
      action: "/settings/passkeys/pk_1?ri=jp",
      scope: "client_passkey",
      description_label: "名前",
      description: null,
      submit_label: "保存",
    },
    cancel_link: { label: "キャンセル", href: "/settings/passkeys" },
    destroy: {
      action: "/settings/passkeys/pk_1?ri=jp",
      submit_label: "削除",
      confirm_message: "削除しますか",
    },
    turnstile,
    error_header: null,
    error_messages: [],
  };

  it("renames with a PATCH under the scope the server named", () => {
    mount(<PasskeysEdit {...editProps} />);

    const field = container.querySelector<HTMLInputElement>("input[type=text]")!;

    typeInto(field, "Renamed");

    expect(setData).toHaveBeenCalledWith("description", "Renamed");

    submitForm();

    expect(transform).toHaveBeenCalled();
    const passkeyTransformer = present(transform.mock.calls[0]?.[0], "a transform callback");
    expect(passkeyTransformer({ description: "Renamed" })).toEqual({
      client_passkey: { description: "Renamed" },
      "cf-turnstile-response": "",
    });
    expect(patch).toHaveBeenCalledWith("/settings/passkeys/pk_1?ri=jp");
  });

  it("removes the passkey with a DELETE once confirmed", () => {
    mount(<PasskeysEdit {...editProps} />);

    clickButton("削除");
    answerConfirmation(true);

    expect(deleteRequest).toHaveBeenCalledWith("/settings/passkeys/pk_1?ri=jp", {
      data: { "cf-turnstile-response": "" },
    });
  });

  it("keeps the passkey when the removal is declined", () => {
    mount(<PasskeysEdit {...editProps} />);

    clickButton("削除");
    answerConfirmation(false);

    expect(deleteRequest).not.toHaveBeenCalled();
  });
});

describe("totp settings interaction", () => {
  it("posts the enrolment under the scope the server named", () => {
    mount(
      <TotpsNew
        title="認証アプリを追加"
        description="認証アプリを登録します"
        back_link={{ label: "もどる", href: "/settings/totps?ri=jp" }}
        qr_code_image="data:image/png;base64,AAAA"
        qr_fallback="QRコードを読み取れない場合"
        form={{
          action: "/settings/totps?ri=jp",
          scope: "user_totp_credential",
          title_label: "名前",
          title_placeholder: "iPhone",
          title_hint: "わかりやすい名前",
          title: null,
          first_token_label: "確認コード",
          first_token_placeholder: "123456",
          first_token_help: "アプリに表示されるコード",
          first_token_delivery_help: "コードはアプリに表示されます",
          submit_label: "登録",
        }}
        cancel_link={{ label: "キャンセル", href: "/settings/totps?ri=jp" }}
        turnstile={turnstile}
        error_header={null}
        error_messages={[]}
      />,
    );

    const inputs = [...container.querySelectorAll<HTMLInputElement>("input[type=text]")];
    typeInto(present(inputs[0], "the title field"), "iPhone");
    typeInto(present(inputs[1], "the first token field"), "123456");

    expect(setData).toHaveBeenCalledWith("title", "iPhone");
    expect(setData).toHaveBeenCalledWith("first_token", "123456");

    submitForm();

    expect(transform).toHaveBeenCalled();
    const totpNewTransformer = present(transform.mock.calls[0]?.[0], "a transform callback");
    expect(totpNewTransformer({ title: "iPhone", first_token: "123456" })).toEqual({
      user_totp_credential: { title: "iPhone", first_token: "123456" },
      "cf-turnstile-response": "",
    });
    expect(post).toHaveBeenCalledWith("/settings/totps?ri=jp");
  });

  const editProps = {
    title: "認証アプリの編集",
    description: "名前を変更します",
    back_link: { label: "もどる", href: "/settings/totps?ri=jp" },
    form: {
      action: "/settings/totps/totp_1?ri=jp",
      scope: "user_totp_credential",
      title_label: "名前",
      title_placeholder: "iPhone",
      title_hint: "わかりやすい名前",
      title: null,
      submit_label: "保存",
    },
    cancel_link: { label: "キャンセル", href: "/settings/totps?ri=jp" },
    destroy: {
      action: "/settings/totps/totp_1?ri=jp",
      submit_label: "削除",
      confirm_message: "削除しますか",
    },
    error_header: "1件のエラー",
    error_messages: ["名前を入力してください"],
  };

  it("renames with a PATCH", () => {
    mount(<TotpsEdit {...editProps} />);

    const field = container.querySelector<HTMLInputElement>("input[type=text]")!;

    typeInto(field, "iPad");

    expect(setData).toHaveBeenCalledWith("title", "iPad");

    submitForm();

    expect(transform).toHaveBeenCalled();
    const totpEditTransformer = present(transform.mock.calls[0]?.[0], "a transform callback");
    expect(totpEditTransformer({ title: "iPad" })).toEqual({
      user_totp_credential: { title: "iPad" },
    });
    expect(patch).toHaveBeenCalledWith("/settings/totps/totp_1?ri=jp");
  });

  it("removes the authenticator with a DELETE once confirmed", () => {
    mount(<TotpsEdit {...editProps} />);

    clickButton("削除");
    answerConfirmation(true);

    expect(deleteRequest).toHaveBeenCalledWith("/settings/totps/totp_1?ri=jp");
  });

  it("keeps the authenticator when the removal is declined", () => {
    mount(<TotpsEdit {...editProps} />);

    clickButton("削除");
    answerConfirmation(false);

    expect(deleteRequest).not.toHaveBeenCalled();
  });
});
