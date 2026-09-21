import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The screens are pure props renderers, so static markup is enough to prove that what the server
// resolved - the copy, the URLs and the rows - is what the page shows. Handlers are exercised in
// settings_screens_interaction.test.tsx.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: vi.fn(), patch: vi.fn(), post: vi.fn() },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData: vi.fn(),
    transform: vi.fn(),
    patch: vi.fn(),
    post: vi.fn(),
    processing: false,
    errors: {},
  }),
  usePage: () => ({ props: {} }),
}));

const { default: SocialLinkStatus } = await import("@/features/auth/settings/SocialLinkStatus");
const { default: SocialLinkManage } = await import("@/features/auth/settings/SocialLinkManage");
const { default: PasskeysIndex } = await import("@/pages/auth/app/settings/passkeys/index");
const { default: PasskeysShow } = await import("@/pages/auth/app/settings/passkeys/show");
const { default: PasskeysNew } = await import("@/pages/auth/app/settings/passkeys/new");
const { default: PasskeysEdit } = await import("@/pages/auth/app/settings/passkeys/edit");
const { default: TotpsIndex } = await import("@/pages/auth/app/settings/totps/index");
const { default: TotpsNew } = await import("@/pages/auth/app/settings/totps/new");
const { default: TotpsEdit } = await import("@/pages/auth/app/settings/totps/edit");

const turnstile = {
  site_key: "site-key",
  mode: "execute" as const,
  action: null,
  cdata: null,
};

describe("social link screens", () => {
  const shared = {
    title: "Apple",
    heading: "Apple",
    description: "Appleアカウントとの連携",
    back_link: { label: "もどる", href: "/settings" },
  };

  it("shows the link status and the way to change it", () => {
    const html = renderToStaticMarkup(
      <SocialLinkStatus
        {...shared}
        status="連携済み"
        edit_link={{ label: "編集", href: "/settings/apple/edit?ri=jp" }}
      />,
    );

    expect(html).toContain("連携済み");
    expect(html).toContain('href="/settings/apple/edit?ri=jp"');
    expect(html).toContain('href="/settings"');
  });

  it("offers a disconnect form with a challenge while another method remains", () => {
    const html = renderToStaticMarkup(
      <SocialLinkManage
        {...shared}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: true,
          blocked_notice: null,
        }}
        connect={null}
        turnstile={turnstile}
      />,
    );

    expect(html).toMatch(/<button[^>]*type="submit"[^>]*>連携解除<\/button>/u);
    expect(html).toContain('name="cf-turnstile-response"');
    // Not `.not.toContain("disabled")`: the button's own Tailwind classes name a `disabled:`
    // variant regardless of state. What must be absent is the actual disabled attribute.
    expect(html).not.toMatch(/\bdisabled(=|\s|>)/u);
  });

  it("disables the disconnect form and explains why when it is the last method", () => {
    const html = renderToStaticMarkup(
      <SocialLinkManage
        {...shared}
        unlink={{
          action: "/settings/apple?ri=jp",
          submit_label: "連携解除",
          allowed: false,
          blocked_notice: "他のログイン方法がありません",
        }}
        connect={null}
        turnstile={null}
      />,
    );

    expect(html).toContain("disabled");
    expect(html).toContain("他のログイン方法がありません");
    expect(html).not.toContain('name="cf-turnstile-response"');
  });

  it("offers a document POST to connect while the provider is unlinked", () => {
    const html = renderToStaticMarkup(
      <SocialLinkManage
        {...shared}
        unlink={null}
        connect={{ action: "/settings/apple?ri=jp", label: "連携する" }}
        turnstile={null}
      />,
    );

    expect(html).toContain('method="post"');
    expect(html).toContain('name="authenticity_token"');
    // The submit control carries the label. Whether it is an `<input type="submit">` or a
    // `<button type="submit">` is presentation; what matters is that the form submits under it.
    expect(html).toMatch(/type="submit"[^>]*>連携する<|value="連携する"/u);
  });
});

describe("passkey settings screens", () => {
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
  };

  it("lists every registered passkey with its actions", () => {
    const html = renderToStaticMarkup(
      <PasskeysIndex
        {...indexProps}
        passkeys={[
          {
            public_id: "pk_1",
            description: "MacBook",
            created_at: "2026/01/01",
            last_used_at: "-",
            edit_href: "/settings/passkeys/pk_1/edit?ri=jp",
            destroy_href: "/settings/passkeys/pk_1?ri=jp",
          },
        ]}
      />,
    );

    expect(html).toContain("MacBook");
    expect(html).toContain('href="/settings/passkeys/pk_1/edit?ri=jp"');
    expect(html).toContain("最終利用");
    expect(html).not.toContain("登録がありません");
  });

  it("explains an empty list", () => {
    const html = renderToStaticMarkup(
      <PasskeysIndex
        {...indexProps}
        passkeys={[]}
      />,
    );

    expect(html).toContain("登録がありません");
  });

  it("shows one passkey in detail without offering removal", () => {
    const html = renderToStaticMarkup(
      <PasskeysShow
        title="Passkey"
        description="登録済みのPasskey"
        back_link={{ label: "もどる", href: "/settings/passkeys?ri=jp" }}
        passkey_description={null}
        details={[{ key: "created_at", label: "作成日", value: "2026/01/01" }]}
        edit_link={{ label: "編集", href: "/settings/passkeys/pk_1/edit?ri=jp" }}
      />,
    );

    expect(html).toContain("作成日");
    expect(html).toContain('href="/settings/passkeys/pk_1/edit?ri=jp"');
    expect(html).not.toContain("削除");
  });

  it("names the passkey when the server sent a description", () => {
    const html = renderToStaticMarkup(
      <PasskeysShow
        title="Passkey"
        description="登録済みのPasskey"
        back_link={{ label: "もどる", href: "/settings/passkeys?ri=jp" }}
        passkey_description="MacBook"
        details={[{ key: "created_at", label: "作成日", value: "2026/01/01" }]}
        edit_link={{ label: "編集", href: "/settings/passkeys/pk_1/edit?ri=jp" }}
      />,
    );

    expect(html).toContain("MacBook");
  });

  it("frames the registration ceremony", () => {
    const html = renderToStaticMarkup(
      <PasskeysNew
        title="Passkeyを追加"
        description="認証器を登録します"
        back_link={{ label: "もどる", href: "/settings/passkeys?ri=jp" }}
        cancel_link={{ label: "キャンセル", href: "/settings/passkeys" }}
        panel={{
          options_url: "/settings/passkeys/options",
          verification_url: "/settings/passkeys/verification",
          turnstile_site_key: "site-key",
          turnstile_error_message: "検証に失敗しました",
          description_label: "名前",
          description_placeholder: "MacBook",
          submit_label: "登録",
        }}
      />,
    );

    expect(html).toContain("Passkeyを追加");
    expect(html).toContain("登録");
    expect(html).toContain('placeholder="MacBook"');
  });

  it("shows the rename form together with the validation errors", () => {
    const html = renderToStaticMarkup(
      <PasskeysEdit
        title="Passkeyの編集"
        description="名前を変更します"
        back_link={{ label: "もどる", href: "/settings/passkeys?ri=jp" }}
        form={{
          action: "/settings/passkeys/pk_1?ri=jp",
          scope: "client_passkey",
          description_label: "名前",
          description: "MacBook",
          submit_label: "保存",
        }}
        cancel_link={{ label: "キャンセル", href: "/settings/passkeys" }}
        destroy={{
          action: "/settings/passkeys/pk_1?ri=jp",
          submit_label: "削除",
          confirm_message: "削除しますか",
        }}
        turnstile={turnstile}
        error_header="1件のエラー"
        error_messages={["名前を入力してください"]}
      />,
    );

    expect(html).toContain("1件のエラー");
    expect(html).toContain("名前を入力してください");
    expect(html).toContain('name="cf-turnstile-response"');
  });
});

describe("totp settings screens", () => {
  const indexProps = {
    title: "Totps",
    back_link: { label: "もどる", href: "/settings" },
    new_link: { label: "追加", href: "/settings/totps/new?ri=jp" },
    columns: { title: "名前", last_otp_at: "最終利用", status: "状態", actions: "Actions" },
    empty_message: "登録がありません",
    edit_label: "編集",
  };

  it("lists every registered authenticator", () => {
    const html = renderToStaticMarkup(
      <TotpsIndex
        {...indexProps}
        totps={[
          {
            public_id: "totp_1",
            title: "iPhone",
            last_otp_at: "-",
            status: "有効",
            edit_href: "/settings/totps/totp_1/edit?ri=jp",
          },
        ]}
      />,
    );

    expect(html).toContain("iPhone");
    expect(html).toContain("有効");
    expect(html).toContain('href="/settings/totps/totp_1/edit?ri=jp"');
    expect(html).not.toContain("登録がありません");
  });

  it("explains an empty list", () => {
    const html = renderToStaticMarkup(
      <TotpsIndex
        {...indexProps}
        totps={[]}
      />,
    );

    expect(html).toContain("登録がありません");
  });

  it("shows the provisioning code and the enrolment form", () => {
    const html = renderToStaticMarkup(
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

    expect(html).toContain('src="data:image/png;base64,AAAA"');
    expect(html).toContain("QRコードを読み取れない場合");
    expect(html).toContain('name="cf-turnstile-response"');
    expect(html).toMatch(/type="submit"[^>]*>登録<|value="登録"/u);
  });

  it("repeats the enrolment errors the server produced", () => {
    const html = renderToStaticMarkup(
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
          title: "iPhone",
          first_token_label: "確認コード",
          first_token_placeholder: "123456",
          first_token_help: "アプリに表示されるコード",
          first_token_delivery_help: "コードはアプリに表示されます",
          submit_label: "登録",
        }}
        cancel_link={{ label: "キャンセル", href: "/settings/totps?ri=jp" }}
        turnstile={turnstile}
        error_header="1件のエラー"
        error_messages={["確認コードが正しくありません"]}
      />,
    );

    expect(html).toContain("1件のエラー");
    expect(html).toContain("確認コードが正しくありません");
  });

  it("shows the rename form and the removal action", () => {
    const html = renderToStaticMarkup(
      <TotpsEdit
        title="認証アプリの編集"
        description="名前を変更します"
        back_link={{ label: "もどる", href: "/settings/totps?ri=jp" }}
        form={{
          action: "/settings/totps/totp_1?ri=jp",
          scope: "user_totp_credential",
          title_label: "名前",
          title_placeholder: "iPhone",
          title_hint: "わかりやすい名前",
          title: "iPhone",
          submit_label: "保存",
        }}
        cancel_link={{ label: "キャンセル", href: "/settings/totps?ri=jp" }}
        destroy={{
          action: "/settings/totps/totp_1?ri=jp",
          submit_label: "削除",
          confirm_message: "削除しますか",
        }}
        error_header={null}
        error_messages={[]}
      />,
    );

    expect(html).toMatch(/type="submit"[^>]*>保存<|value="保存"/u);
    expect(html).toContain("削除");
    expect(html).not.toContain('name="cf-turnstile-response"');
  });
});
