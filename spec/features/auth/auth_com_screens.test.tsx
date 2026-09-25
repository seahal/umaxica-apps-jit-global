import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The screens submit through Inertia's `useForm` and draw the Cloudflare challenge, neither of
// which exists outside a booted application. Both are stubbed to what they render so the static
// markup stays assertable; the ceremonies themselves are covered by their own specs.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { patch: vi.fn(), post: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: { errors: { base: "資格情報が正しくありません" } } }),
  useForm: (initial: Record<string, unknown>) => {
    const errors: Record<string, string> = {
      pass_code: "コードが正しくありません",
      address: "メールアドレスを入力してください",
    };

    return {
      data: initial,
      setData: vi.fn(),
      errors,
      processing: false,
      post: vi.fn(),
      patch: vi.fn(),
    };
  },
}));

vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: ({ site_key: siteKey }: { site_key: string }) => (
    <div data-turnstile-site-key={siteKey} />
  ),
}));

vi.mock("@/features/auth/passkeys/PasskeyAuthenticationPanel", () => ({
  default: ({ submit_label: submitLabel }: { submit_label: string }) => (
    <button type="button">{submitLabel}</button>
  ),
}));

vi.mock("@/features/auth/passkeys/PasskeyRegistrationPanel", () => ({
  default: ({ submit_label: submitLabel }: { submit_label: string }) => (
    <button type="button">{submitLabel}</button>
  ),
}));

const { default: AuthMethodChoice } = await import("@/features/auth/AuthMethodChoice");
const { default: SignInMethodChoice } = await import("@/features/auth/signin/SignInMethodChoice");
const { default: MfaChallengeChoice } = await import("@/features/auth/MfaChallengeChoice");
const { default: VerificationSetup } = await import("@/features/auth/VerificationSetup");
const { default: SignInEmailNew } = await import("@/features/auth/SignInEmailNew");
const { default: SignInEmailEdit } = await import("@/features/auth/SignInEmailEdit");
const { default: SignInPasskeyNew } = await import("@/features/auth/SignInPasskeyNew");
const { default: PasskeyIndex } = await import("@/features/auth/settings/PasskeyIndex");
const { default: PasskeyShow } = await import("@/features/auth/settings/PasskeyShow");
const { default: PasskeyEdit } = await import("@/features/auth/settings/PasskeyEdit");
const { default: PasskeyNew } = await import("@/features/auth/settings/PasskeyNew");

const { default: ComSignInsNew } = await import("@/pages/auth/com/sign_ins/new");
const { default: ComSignUpsNew } = await import("@/pages/auth/com/sign_ups/new");
const { default: ComChallengesShow } = await import("@/pages/auth/com/sign/in/challenges/show");
const { default: ComSetupsNew } = await import("@/pages/auth/com/verification/setups/new");
const { default: ComEmailsNew } = await import("@/pages/auth/com/sign/in/emails/new");
const { default: ComEmailsEdit } = await import("@/pages/auth/com/sign/in/emails/edit");
const { default: ComPasskeysNew } = await import("@/pages/auth/com/sign/in/passkeys/new");
const { default: ComSettingsIndex } = await import("@/pages/auth/com/settings/passkeys/index");
const { default: ComSettingsShow } = await import("@/pages/auth/com/settings/passkeys/show");
const { default: ComSettingsEdit } = await import("@/pages/auth/com/settings/passkeys/edit");
const { default: ComSettingsNew } = await import("@/pages/auth/com/settings/passkeys/new");

const turnstile = {
  site_key: "site-key",
  mode: "render" as const,
  action: null,
  cdata: null,
};

describe("AuthMethodChoice", () => {
  const props = {
    title: "ログイン",
    description: "方法を選びます。",
    suspended_notice: null,
    methods: [{ key: "email", label: "メール", href: "/sign/in/email/new" }],
    links: [{ key: "registration", label: "登録", href: "/sign/up" }],
  };

  it("lists the methods and the trailing links the server resolved", () => {
    const markup = renderToStaticMarkup(<AuthMethodChoice {...props} />);

    expect(markup).toMatch(/<h1[^>]*>ログイン<\/h1>/u);
    expect(markup).toContain("方法を選びます。");
    // The row carries a decorative arrow beside the label, so the label sits in a span rather
    // than directly in the anchor. What the assertion is for is that the method links there under
    // that name.
    expect(markup).toMatch(/<a href="\/sign\/in\/email\/new"[\s\S]*?>メール</u);
    expect(markup).toMatch(/<a href="\/sign\/up"[^>]*>登録<\/a>/u);
  });

  it("shows the suspension notice instead of any entry point", () => {
    const markup = renderToStaticMarkup(
      <AuthMethodChoice
        {...props}
        suspended_notice="受付を停止しています"
        methods={[]}
        links={[]}
      />,
    );

    expect(markup).toContain('data-test-id="sign-up-suspended"');
    expect(markup).toContain("受付を停止しています");
    expect(markup).not.toContain("<h1>");
  });

  it("omits the description when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <AuthMethodChoice
        {...props}
        description={null}
      />,
    );

    expect(markup).not.toContain("方法を選びます。");
  });
});

describe("MfaChallengeChoice", () => {
  it("offers the factor the actor holds", () => {
    const markup = renderToStaticMarkup(
      <MfaChallengeChoice
        title="二段階認証"
        description="続けます。"
        methods={[{ key: "passkey", label: "パスキー", href: "/sign/in/challenge/passkey/new" }]}
        no_methods_notice={null}
        back_link={null}
      />,
    );

    // As above: the row carries a decorative arrow, so the label sits in a span.
    expect(markup).toMatch(/<a href="\/sign\/in\/challenge\/passkey\/new"[\s\S]*?>パスキー</u);
  });

  it("falls back to the notice and the way back when no factor is available", () => {
    const markup = renderToStaticMarkup(
      <MfaChallengeChoice
        title="二段階認証"
        description="続けます。"
        methods={[]}
        no_methods_notice="利用できる方法がありません"
        back_link={{ key: "back", label: "もどる", href: "/sign/in" }}
      />,
    );

    expect(markup).toContain("利用できる方法がありません");
    expect(markup).toMatch(/<a href="\/sign\/in"[^>]*>もどる<\/a>/u);
  });
});

describe("VerificationSetup", () => {
  it("offers only the missing methods, with the back link when there is one", () => {
    const markup = renderToStaticMarkup(
      <VerificationSetup
        title="本人確認の設定"
        description="方法を追加します。"
        back_link={{ key: "back", label: "もどる", href: "/settings" }}
        methods={[{ key: "passkey", label: "パスキー", href: "/settings/passkey/new" }]}
      />,
    );

    expect(markup).toMatch(/<a href="\/settings"[^>]*>もどる<\/a>/u);
    // As above: the row carries a decorative arrow, so the label sits in a span.
    expect(markup).toMatch(/<a href="\/settings\/passkey\/new"[\s\S]*?>パスキー</u);
  });

  it("omits the back link when the ceremony carried no destination", () => {
    const markup = renderToStaticMarkup(
      <VerificationSetup
        title="本人確認の設定"
        description="方法を追加します。"
        back_link={null}
        methods={[]}
      />,
    );

    expect(markup).not.toContain("もどる");
  });
});

describe("sign-in credential screens", () => {
  it("SignInEmailNew renders the address field and the challenge", () => {
    const markup = renderToStaticMarkup(
      <SignInEmailNew
        title="メールでログイン"
        description="説明"
        action="/sign/in/email"
        pt={null}
        field_label="メールアドレス"
        submit_label="送信"
        back_link={{ label: "もどる", href: "/sign/in" }}
        turnstile={turnstile}
      />,
    );

    expect(markup).toContain('name="user_email[address]"');
    expect(markup).toContain("メールアドレスを入力してください");
    expect(markup).toContain('data-turnstile-site-key="site-key"');
    expect(markup).toContain('href="/sign/in"');
  });

  it("SignInEmailEdit renders the one-time code field and the resend control", () => {
    const markup = renderToStaticMarkup(
      <SignInEmailEdit
        title="コードの入力"
        description="説明"
        action="/sign/in/email"
        pt="token"
        field_label="コード"
        field_placeholder="000000"
        submit_label="確認"
        delivery_help="届かない場合"
        return_link={{ label: "もどる", href: "/sign/in/email/new" }}
        resend={{
          endpoint: "/web/v0/in/email/otp",
          state: "resend-state",
          messages: {
            button_label: "再送信",
            sent_message: "送信しました",
            too_soon_message: "しばらく待ってください",
            failed_message: "失敗しました",
          },
        }}
        turnstile={turnstile}
      />,
    );

    expect(markup).toContain('name="user_email[pass_code]"');
    expect(markup).toContain("再送信");
    expect(markup).toContain("届かない場合");
  });

  it("SignInEmailEdit shows the code error and omits a pending-token field", () => {
    const markup = renderToStaticMarkup(
      <SignInEmailEdit
        title="コードの入力"
        description="説明"
        action="/sign/in/email"
        pt={null}
        field_label="コード"
        field_placeholder="000000"
        submit_label="確認"
        delivery_help="届かない場合"
        return_link={{ label: "もどる", href: "/sign/in/email/new" }}
        resend={{
          endpoint: "/web/v0/in/email/otp",
          state: "resend-state",
          messages: {
            button_label: "再送信",
            sent_message: "送信しました",
            too_soon_message: "しばらく待ってください",
            failed_message: "失敗しました",
          },
        }}
        turnstile={turnstile}
      />,
    );

    expect(markup).not.toContain('name="pt"');
    expect(markup).toContain("コードが正しくありません");
  });

  it("SignInPasskeyNew frames the shared ceremony panel", () => {
    const markup = renderToStaticMarkup(
      <SignInPasskeyNew
        title="パスキーでログイン"
        description="説明"
        panel={{
          options_url: "/sign/in/passkey/options",
          verification_url: "/sign/in/passkey/verification",
          region: "jp",
          identifier_param: "identifier",
          turnstile_site_key: "site-key",
          turnstile_error_message: "失敗",
          field: {
            label: "ID",
            placeholder: "name@example.com",
            min_length: 0,
            max_length: 255,
            pattern: ".*",
          },
          submit_label: "認証",
        }}
        back_link={{ label: "もどる", href: "/sign/in" }}
      />,
    );

    expect(markup).toContain("認証");
    expect(markup).toMatch(/<a href="\/sign\/in"[^>]*>もどる<\/a>/u);
  });
});

describe("passkey settings screens", () => {
  const row = {
    public_id: "pk_1",
    description: "MacBook",
    created_at: "2026/01/01",
    edit_href: "/settings/passkey/pk_1/edit",
    destroy_href: "/settings/passkey/pk_1",
  };

  it("PasskeyIndex lists every registered passkey", () => {
    const markup = renderToStaticMarkup(
      <PasskeyIndex
        title="パスキー"
        add_link={{ label: "追加", href: "/settings/passkey/new" }}
        back_link={{ label: "もどる", href: "/settings" }}
        columns={{ description: "説明", created_at: "登録日", actions: "操作" }}
        passkeys={[row]}
        empty_message="登録がありません"
        edit_label="編集"
        destroy_label="削除"
        confirm_message="削除しますか"
        turnstile={{ ...turnstile, mode: "execute" }}
      />,
    );

    expect(markup).toContain("MacBook");
    expect(markup).toMatch(/<a href="\/settings\/passkey\/pk_1\/edit"[^>]*>編集<\/a>/u);
    expect(markup).not.toContain("登録がありません");
  });

  it("PasskeyIndex shows the empty row when there is nothing registered", () => {
    const markup = renderToStaticMarkup(
      <PasskeyIndex
        title="パスキー"
        add_link={{ label: "追加", href: "/settings/passkey/new" }}
        back_link={{ label: "もどる", href: "/settings" }}
        columns={{ description: "説明", created_at: "登録日", actions: "操作" }}
        passkeys={[]}
        empty_message="登録がありません"
        edit_label="編集"
        destroy_label="削除"
        confirm_message="削除しますか"
        turnstile={{ ...turnstile, mode: "execute" }}
      />,
    );

    expect(markup).toContain('colSpan="3"');
    expect(markup).toContain("登録がありません");
  });

  it("PasskeyShow renders the details the server formatted", () => {
    const markup = renderToStaticMarkup(
      <PasskeyShow
        title="パスキー"
        back_link={{ label: "もどる", href: "/settings/passkey" }}
        details={[{ key: "description", label: "説明", value: "MacBook" }]}
        edit_link={{ label: "編集", href: "/settings/passkey/pk_1/edit" }}
        destroy_href="/settings/passkey/pk_1"
        destroy_label="削除"
        confirm_message="削除しますか"
        turnstile={{ ...turnstile, mode: "execute" }}
      />,
    );

    expect(markup).toMatch(/<dt[^>]*>説明<\/dt>/u);
    expect(markup).toMatch(/<dd[^>]*>MacBook<\/dd>/u);
  });

  it("PasskeyEdit scopes the description field to the permitted parameter", () => {
    const markup = renderToStaticMarkup(
      <PasskeyEdit
        title="パスキーの編集"
        action="/settings/passkey/pk_1"
        field_label="説明"
        description="MacBook"
        submit_label="保存"
        cancel_link={{ label: "中止", href: "/settings/passkey" }}
        turnstile={{ ...turnstile, mode: "execute" }}
      />,
    );

    expect(markup).toContain('name="visitor_passkey[description]"');
    expect(markup).toContain('value="MacBook"');
  });

  it("PasskeyNew frames the shared registration panel", () => {
    const markup = renderToStaticMarkup(
      <PasskeyNew
        title="パスキーの登録"
        description="説明"
        panel={{
          options_url: "/settings/passkey/options",
          verification_url: "/settings/passkey/verification",
          turnstile_site_key: "site-key",
          turnstile_error_message: "失敗",
          description_label: "説明",
          description_placeholder: "MacBook",
          submit_label: "登録",
        }}
        cancel_link={{ label: "中止", href: "/settings/passkey" }}
      />,
    );

    expect(markup).toContain("登録");
    expect(markup).toMatch(/<a href="\/settings\/passkey"[^>]*>中止<\/a>/u);
  });
});

describe("auth/com page modules", () => {
  it("re-export the shared screens rather than defining their own", () => {
    // Signing in and signing up offer different method sets, so they are different screens.
    expect(ComSignInsNew).toBe(SignInMethodChoice);
    expect(ComSignUpsNew).toBe(AuthMethodChoice);
    expect(ComChallengesShow).toBe(MfaChallengeChoice);
    expect(ComSetupsNew).toBe(VerificationSetup);
    expect(ComEmailsNew).toBe(SignInEmailNew);
    expect(ComEmailsEdit).toBe(SignInEmailEdit);
    expect(ComPasskeysNew).toBe(SignInPasskeyNew);
    expect(ComSettingsIndex).toBe(PasskeyIndex);
    expect(ComSettingsShow).toBe(PasskeyShow);
    expect(ComSettingsEdit).toBe(PasskeyEdit);
    expect(ComSettingsNew).toBe(PasskeyNew);
  });
});
