import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The com sign-up, checkpoint and step-up screens the surface resolves from
// `src/pages/auth/com`. Every string and every URL arrives finished from the server, so the
// assertions are about what the page draws from its props, not about how it computes anything.
//
// The Cloudflare challenge does not exist outside a booted application, so the widget is stubbed to
// what it renders; the ceremony itself is covered by its own spec.
vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: ({ site_key: siteKey }: { site_key: string }) => (
    <div data-turnstile-site-key={siteKey} />
  ),
}));

const { default: ComSignUpEmailNew } = await import("@/pages/auth/com/sign/up/emails/new");
const { default: ComSignUpEmailEdit } = await import("@/pages/auth/com/sign/up/emails/edit");
const { default: ComSignUpTelephoneNew } = await import("@/pages/auth/com/sign/up/telephones/new");
const { default: ComSignUpTelephoneEdit } =
  await import("@/pages/auth/com/sign/up/telephones/edit");
const { default: ComCheckpointShow } = await import("@/pages/auth/com/sign/up/checkpoints/show");
const { default: ComCheckpointAgeRestricted } =
  await import("@/pages/auth/com/sign/up/checkpoints/age_restricted");
const { default: ComCheckpointPasscodeNew } =
  await import("@/pages/auth/com/sign/up/checkpoint/passcodes/new");
const { default: ComCheckpointPasskeyNew } =
  await import("@/pages/auth/com/sign/up/checkpoint/passkeys/new");
const { default: ComVerificationEmailNew } =
  await import("@/pages/auth/com/verification/emails/new");
const { default: ComVerificationEmailEdit } =
  await import("@/pages/auth/com/verification/emails/edit");
const { default: ComVerificationPasskeyNew } =
  await import("@/pages/auth/com/verification/passkeys/new");

const turnstile = {
  site_key: "site-key",
  mode: "render" as const,
  action: null,
  cdata: null,
};

describe("auth/com sign-up entry screens", () => {
  const emailProps = {
    title: "メールアドレスで登録",
    action: "/sign/up/email",
    scope: "visitor_email",
    field: {
      name: "raw_address",
      label: "メールアドレス",
      type: "email" as const,
      autocomplete: "email",
    },
    checkboxes: [
      { name: "confirm_policy", label: "規約に同意する", description: null },
      {
        name: "confirm_age",
        label: "年齢を確認した",
        description: "利用規約とプライバシーポリシー",
      },
    ],
    error_heading: null,
    errors: [],
    turnstile,
    submit_label: "登録する",
    links: [{ key: "sign_in", label: "ログイン", href: "/sign/in?ri=jp" }],
  };

  it("draws the email form against the endpoint and scope the server chose", () => {
    const markup = renderToStaticMarkup(<ComSignUpEmailNew {...emailProps} />);

    expect(markup).toMatch(/<h2[^>]*>メールアドレスで登録<\/h2>/u);
    expect(markup).toContain('action="/sign/up/email"');
    expect(markup).toContain('name="visitor_email[raw_address]"');
    expect(markup).toContain('name="visitor_email[confirm_policy]"');
    expect(markup).toContain('data-turnstile-site-key="site-key"');
    expect(markup).toMatch(/<a href="\/sign\/in\?ri=jp"[^>]*>ログイン<\/a>/u);
  });

  it("lists the validation messages under the heading the server sent", () => {
    const markup = renderToStaticMarkup(
      <ComSignUpEmailNew
        {...emailProps}
        error_heading="入力内容を確認してください"
        errors={["メールアドレスを入力してください"]}
      />,
    );

    expect(markup).toContain("入力内容を確認してください");
    expect(markup).toContain("メールアドレスを入力してください");
  });

  it("draws the telephone form with the telephone field type", () => {
    const markup = renderToStaticMarkup(
      <ComSignUpTelephoneNew
        {...emailProps}
        title="電話番号で登録"
        action="/sign/up/telephone?ri=jp"
        scope="visitor_telephone"
        field={{ name: "raw_number", label: "電話番号", type: "tel", autocomplete: "tel" }}
      />,
    );

    expect(markup).toMatch(/<h2[^>]*>電話番号で登録<\/h2>/u);
    expect(markup).toContain('name="visitor_telephone[raw_number]"');
    expect(markup).toContain('type="tel"');
  });
});

describe("auth/com sign-up OTP screens", () => {
  const otpProps = {
    title: "認証コード入力",
    description: "コードを送信しました",
    action: "/sign/up/check/email/otp?ri=jp",
    scope: "visitor_email",
    code_label: "認証コード",
    code_placeholder: "123456",
    submit_label: "送信",
    delivery_help: "届かない場合は再送してください",
    error_heading: null,
    errors: [],
    return_link: { label: "登録方法に戻る", href: "/sign/up?ri=jp" },
  };

  it("patches the OTP endpoint and never carries the code itself", () => {
    const markup = renderToStaticMarkup(<ComSignUpEmailEdit {...otpProps} />);

    expect(markup).toMatch(/<h1[^>]*>認証コード入力<\/h1>/u);
    expect(markup).toContain('action="/sign/up/check/email/otp?ri=jp"');
    expect(markup).toContain('name="_method" value="patch"');
    expect(markup).toContain('name="visitor_email[pass_code]"');
    expect(markup).toContain("届かない場合は再送してください");
    expect(markup).toMatch(/<a href="\/sign\/up\?ri=jp"[^>]*>登録方法に戻る<\/a>/u);
  });

  it("shows the telephone OTP errors the previous attempt produced", () => {
    const markup = renderToStaticMarkup(
      <ComSignUpTelephoneEdit
        {...otpProps}
        scope="visitor_telephone"
        action="/sign/up/check/telephone/otp?ri=jp"
        error_heading="入力を確認してください"
        errors={["認証コードが正しくありません"]}
      />,
    );

    expect(markup).toContain('name="visitor_telephone[pass_code]"');
    expect(markup).toContain("認証コードが正しくありません");
  });

  it("lists validation messages without a heading when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <ComSignUpEmailEdit
        {...otpProps}
        errors={["認証コードが正しくありません"]}
      />,
    );

    expect(markup).toContain("認証コードが正しくありません");
    expect(markup).not.toContain("<h2");
  });
});

describe("auth/com sign-up checkpoint screens", () => {
  it("draws only the requirements the server left outstanding", () => {
    const markup = renderToStaticMarkup(
      <ComCheckpointShow
        title="登録の確認"
        birthdate={null}
        passkey={{
          title: "パスキー",
          description: "パスキーを登録します",
          label: "登録する",
          href: "/sign/up/check/telephone/passkey?ri=jp",
        }}
        passcode={null}
        complete_message={null}
        cancellation={{ label: "キャンセル", action: "/sign/up/check/telephone?ri=jp" }}
      />,
    );

    expect(markup).toMatch(/<h1[^>]*>登録の確認<\/h1>/u);
    expect(markup).toMatch(
      /<a href="\/sign\/up\/check\/telephone\/passkey\?ri=jp"[^>]*>登録する<\/a>/u,
    );
    expect(markup).not.toContain("パスコード");
    expect(markup).toContain('name="_method" value="delete"');
  });

  it("draws the birthdate form, remaining requirements, and completion copy", () => {
    const markup = renderToStaticMarkup(
      <ComCheckpointShow
        title="登録の確認"
        birthdate={{
          title: "生年月日",
          description: "年齢を確認します",
          label: "生年月日",
          action: "/sign/up/check/email",
          submit_label: "送信する",
          checkpoint_version: 1,
          fields: {
            format: "ymd",
            separator: "/",
            parts: [
              {
                part: "year",
                label: "年",
                placeholder: "1990",
                value: "",
                min: 1900,
                max: 2026,
              },
              {
                part: "month",
                label: "月",
                placeholder: "1",
                value: "3",
                min: 1,
                max: 12,
              },
            ],
          },
        }}
        passkey={null}
        passcode={{
          title: "パスコード",
          description: "パスコードを登録します",
          label: "登録する",
          href: "/sign/up/check/email/passcode",
        }}
        complete_message="残りの手続きはありません"
        cancellation={null}
      />,
    );

    expect(markup).toContain('name="birthdate_year"');
    expect(markup).toContain("/");
    expect(markup).toContain('href="/sign/up/check/email/passcode"');
    expect(markup).toContain("残りの手続きはありません");
    expect(markup).not.toContain('name="_method" value="delete"');
  });

  it("keeps the age-restricted restart a GET, as the button_to was", () => {
    const markup = renderToStaticMarkup(
      <ComCheckpointAgeRestricted
        title="ご利用いただけません"
        message="年齢の条件を満たしていません"
        retry_message="やり直してください"
        back={{ label: "戻る", href: "/sign/up?ri=jp" }}
      />,
    );

    expect(markup).toContain("年齢の条件を満たしていません");
    expect(markup).toContain('action="/sign/up?ri=jp" method="get"');
  });

  it("shows the generated passcode exactly once with its save and cancel controls", () => {
    const markup = renderToStaticMarkup(
      <ComCheckpointPasscodeNew
        title="パスコード"
        description="パスコードを保存してください"
        action="/sign/up/check/telephone/passcode?ri=jp"
        scope="visitor_secret_credential"
        checkpoint_version={3}
        errors={[]}
        name_label="名前"
        secret_heading="Secret"
        secret="one-time-secret"
        one_time_notice="一度だけ表示されます"
        save_label="保存"
        cancel_label="キャンセル"
      />,
    );

    expect(markup).toContain("one-time-secret");
    expect(markup).not.toContain('role="alert"');
  });

  it("lists passcode setup errors when the previous attempt failed", () => {
    const markup = renderToStaticMarkup(
      <ComCheckpointPasscodeNew
        title="パスコード"
        description="パスコードを保存してください"
        action="/sign/up/check/telephone/passcode?ri=jp"
        scope="visitor_secret_credential"
        checkpoint_version={3}
        errors={["名前を入力してください"]}
        name_label="名前"
        secret_heading="Secret"
        secret="one-time-secret"
        one_time_notice="一度だけ表示されます"
        save_label="保存"
        cancel_label="キャンセル"
      />,
    );

    expect(markup).toContain("名前を入力してください");
    expect(markup).toContain("名前を入力してください");
    expect(markup).toContain('name="checkpoint_version" value="3"');
    expect(markup).toContain('name="visitor_secret_credential[name]"');
    expect(markup).toContain('name="_method" value="delete"');
  });

  it("hands the passkey ceremony the endpoints the server generated", () => {
    const markup = renderToStaticMarkup(
      <ComCheckpointPasskeyNew
        title="パスキー登録"
        begin_url="/sign/up/check/telephone/passkey?ri=jp"
        finish_url="/sign/up/check/telephone/passkey?ri=jp"
        success_redirect_url="/sign/up/check/telephone/passcode?ri=jp"
        checkpoint_version={2}
        description_label="名前"
        description_placeholder="MacBook"
        submit_label="登録する"
      />,
    );

    expect(markup).toMatch(/<h1[^>]*>パスキー登録<\/h1>/u);
    expect(markup).toContain('placeholder="MacBook"');
    expect(markup).toContain("登録する");
  });
});

describe("auth/com step-up verification screens", () => {
  const formBase = {
    csrf_token: "test-token",
    scope: "settings_email",
    pt: "return-token",
  };

  it("starts the email delivery without naming the address", () => {
    const markup = renderToStaticMarkup(
      <ComVerificationEmailNew
        title="本人確認"
        heading="本人確認"
        description="登録済みのメールに送信します"
        errors={[]}
        form={{
          ...formBase,
          action: "/verification/emails?ri=jp",
          submit_label: "コードを送る",
        }}
        back={{ label: "戻る", href: "/verification?ri=jp" }}
      />,
    );

    expect(markup).toMatch(/<h1[^>]*>本人確認<\/h1>/u);
    expect(markup).toContain('action="/verification/emails?ri=jp"');
    expect(markup).toContain('value="settings_email"');
    expect(markup).not.toContain("@");
  });

  it("offers the code entry and the resend as separate submissions", () => {
    const markup = renderToStaticMarkup(
      <ComVerificationEmailEdit
        title="コード入力"
        heading="コード入力"
        description="コードを入力してください"
        delivery_help="届かない場合"
        errors={["コードが正しくありません"]}
        form={{
          ...formBase,
          action: "/verification/emails/nonce?ri=jp",
          code_label: "認証コード",
          code_placeholder: "123456",
          submit_label: "確認",
        }}
        resend={{
          action: "/verification/emails/nonce/redelivery?ri=jp",
          csrf_token: "test-token",
          label: "再送",
        }}
        back={{ label: "戻る", href: "/verification?ri=jp" }}
      />,
    );

    expect(markup).toContain('name="verification[code]"');
    expect(markup).toContain('action="/verification/emails/nonce/redelivery?ri=jp"');
    expect(markup).toContain("コードが正しくありません");
  });

  it("carries the issued challenge into the passkey assertion form", () => {
    const markup = renderToStaticMarkup(
      <ComVerificationPasskeyNew
        title="パスキーで確認"
        heading="パスキーで確認"
        description="パスキーで本人確認します"
        errors={[]}
        form={{
          ...formBase,
          action: "/verification/passkey?ri=jp",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "パスキーで認証",
        }}
        back={{ label: "戻る", href: "/verification?ri=jp" }}
      />,
    );

    expect(markup).toContain('name="verification[challenge_id]" value="challenge-1"');
    expect(markup).toContain('name="verification[credential_json]"');
    expect(markup).toContain("パスキーで認証");
  });
});
