import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

import { present } from "../../../support/present";

// The ceremony pages submit through `useForm`, which does not exist outside a booted Inertia
// application, so it is stubbed to an inert form state and the static markup stays assertable.
vi.mock("@inertiajs/react", () => ({
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    processing: false,
  }),
}));

const { default: SignInMethodChoice } = await import("@/features/auth/signin/SignInMethodChoice");
const { default: EmailSignInForm } = await import("@/features/auth/signin/EmailSignInForm");
const { default: EmailPassCodeForm } = await import("@/features/auth/signin/EmailPassCodeForm");
const { default: TotpChallengeForm } = await import("@/features/auth/signin/TotpChallengeForm");
const { default: PasskeySignInScreen } = await import("@/features/auth/signin/PasskeySignInScreen");
const { default: StepUpPasskeyScreen } = await import("@/features/auth/signin/StepUpPasskeyScreen");

const turnstile = {
  site_key: "site-key",
  mode: "render" as const,
  action: null,
  cdata: null,
};

const backLink = { label: "もどる", href: "/sign/in?ri=jp" };

describe("sign-in method choice", () => {
  const props = {
    title: "ログイン",
    description: "方法を選びます。",
    methods: [
      { key: "email", label: "メール", href: "/sign/in/email/new?ri=jp" },
      { key: "passkey", label: "パスキー", href: "/sign/in/passkey/new?ri=jp" },
    ],
    social_providers: [
      {
        key: "google",
        label: "Googleでログイン",
        action: "/social/google/session?ri=jp",
        authenticity_token: "csrf-value",
        aria_label: "Sign in with Google",
        artwork: {
          light: "/images/social/google_sign_in_light.svg",
          dark: "/images/social/google_sign_in_dark.svg",
          width: 180,
          height: 40,
        },
        logos: null,
      },
      {
        key: "apple",
        label: "Appleで続行",
        action: "/social/apple/session?ri=jp",
        authenticity_token: "csrf-value",
        aria_label: null,
        artwork: null,
        logos: {
          white: "/images/social/apple_logo_white.svg",
          black: "/images/social/apple_logo_black.svg",
          width: 28,
          height: 40,
        },
      },
      {
        key: "entra",
        label: "Entraで続行",
        action: "/social/entra/session?ri=jp",
        authenticity_token: "csrf-value",
        aria_label: null,
        artwork: {
          light: "/images/social/entra_light.svg",
          dark: "/images/social/entra_dark.svg",
          width: 180,
          height: 40,
        },
        logos: null,
      },
    ],
    registration_link: { key: "registration", label: "Need an account", href: "/sign/up?ri=jp" },
  };

  it("renders app methods, native providers, separator, registration and text-only cancel in order", () => {
    const markup = renderToStaticMarkup(
      <SignInMethodChoice
        {...props}
        methods={[
          { key: "email", label: "Email", href: "/sign/in/email/new" },
          { key: "passkey", label: "Passkey", href: "/sign/in/passkey/new" },
          { key: "emergency", label: "Emergency", href: "/sign/in/emergency" },
          { key: "device", label: "Device", href: "/sign/in/device" },
        ]}
        social_providers={props.social_providers.slice(0, 2)}
        cancel_label="Cancel"
      />,
    );
    expect(markup).toMatch(
      />Email<.*>Passkey<.*>Emergency<.*>Device<.*action="\/social\/google\/session\?ri=jp".*action="\/social\/apple\/session\?ri=jp".*<hr[^>]*>.*>Need an account<.*<p[^>]*>Cancel<\/p>/su,
    );
    expect(markup).toMatch(/<p[^>]*>Cancel<\/p>/u);
    const interactiveElements = markup.match(/<(a|button|form)\b[^>]*>[^]*?<\/\1>/gu) ?? [];
    expect(interactiveElements.some((element) => element.includes("Cancel"))).toBe(false);
    expect(markup.match(/<form[^>]*method="post"/gu)).toHaveLength(2);
    expect(markup.match(/name="authenticity_token" value="csrf-value"/gu)).toHaveLength(2);
  });

  it("appends text-only Cancel on com without app methods or a provider separator", () => {
    const markup = renderToStaticMarkup(
      <SignInMethodChoice
        {...props}
        social_providers={[]}
        cancel_label="Cancel"
      />,
    );
    expect(markup).toMatch(/<p[^>]*>Cancel<\/p><\/div>$/u);
    const controls = markup.match(/<(a|button|form)\b[^>]*>[^]*?<\/\1>/gu) ?? [];
    expect(controls.some((control) => control.includes("Cancel"))).toBe(false);
    expect(markup).not.toContain("<hr");
    expect(markup).not.toContain("/sign/in/emergency");
    expect(markup).not.toContain("/sign/in/device");
  });

  it("omits optional Cancel and app-only methods and separator", () => {
    const markup = renderToStaticMarkup(
      <SignInMethodChoice
        {...props}
        social_providers={[]}
      />,
    );
    expect(markup).not.toContain("<hr");
    expect(markup).not.toContain("Cancel");
    expect(markup).not.toContain("/sign/in/emergency");
    expect(markup).not.toContain("/sign/in/device");
  });

  it("lists every method the server offered", () => {
    const markup = renderToStaticMarkup(<SignInMethodChoice {...props} />);

    expect(markup).toContain('href="/sign/in/email/new?ri=jp"');
    expect(markup).toContain('href="/sign/in/passkey/new?ri=jp"');
    expect(markup).toContain("Need an account");
  });

  it("posts each provider hand-off natively with its own authenticity token", () => {
    const markup = renderToStaticMarkup(<SignInMethodChoice {...props} />);

    expect(markup).toContain('action="/social/google/session?ri=jp"');
    expect(markup).toContain('action="/social/apple/session?ri=jp"');
    expect(markup.match(/name="authenticity_token"/gu)).toHaveLength(3);
    expect(markup).toContain('data-turbo="false"');
  });

  it("renders Google's official artwork under its own accessible name", () => {
    const markup = renderToStaticMarkup(<SignInMethodChoice {...props} />);

    expect(markup).toContain('aria-label="Sign in with Google"');
    expect(markup).toContain("/images/social/google_sign_in_light.svg");
    expect(markup).toContain("/images/social/google_sign_in_dark.svg");
  });

  it("renders Apple's official logo pair beside a permitted call to action", () => {
    const markup = renderToStaticMarkup(<SignInMethodChoice {...props} />);

    expect(markup).toContain("/images/social/apple_logo_white.svg");
    expect(markup).toContain("/images/social/apple_logo_black.svg");
    expect(markup).toContain("Appleで続行");
  });

  it("renders a title-only button for a provider that sent no artwork", () => {
    const markup = renderToStaticMarkup(<SignInMethodChoice {...props} />);

    expect(markup).toContain("social-provider-button--entra");
    expect(markup).toContain("Entraで続行");
  });

  it("omits the Apple logo when the deployment does not carry the artwork", () => {
    const withoutLogos = {
      ...props,
      social_providers: [
        { ...present(props.social_providers[1], "the Apple provider fixture"), logos: null },
      ],
    };
    const markup = renderToStaticMarkup(<SignInMethodChoice {...withoutLogos} />);

    expect(markup).not.toContain("apple_logo_white.svg");
    expect(markup).toContain("Appleで続行");
  });
});

describe("email sign-in form", () => {
  const props = {
    title: "メールでログイン",
    description: "免責事項",
    form: {
      action: "/sign/in/email",
      method: "post",
      pt: null,
      address_field: {
        scope: "client_email",
        field: "address",
        name: "client_email[address]",
        label: "メールアドレス",
        placeholder: "name@example.com",
      },
      submit_label: "送信する",
    },
    turnstile,
    form_errors: [],
    back_link: backLink,
  };

  it("renders the address field the server named", () => {
    const markup = renderToStaticMarkup(<EmailSignInForm {...props} />);

    expect(markup).toContain('name="client_email[address]"');
    expect(markup).toContain('placeholder="name@example.com"');
    expect(markup).toContain("送信する");
  });

  it("shows the validation messages the server returned", () => {
    const markup = renderToStaticMarkup(
      <EmailSignInForm
        {...props}
        form_errors={["Addressを入力してください"]}
      />,
    );

    expect(markup).toContain("Addressを入力してください");
    expect(markup).toContain("animate-shake");
  });
});

describe("email pass code form", () => {
  const props = {
    title: "認証コード入力",
    description: "メールアドレスに届きます",
    form: {
      action: "/sign/in/email",
      method: "patch",
      pt: "signed-pt",
      pass_code_field: {
        scope: "client_email",
        field: "pass_code",
        name: "client_email[pass_code]",
        label: "認証コード",
        placeholder: "6桁の数字を入力",
        max_length: 6,
        autocomplete: "one-time-code",
        inputmode: "numeric" as const,
        pattern: "[0-9]*",
      },
      submit_label: "送信する",
    },
    otp_resend: {
      endpoint: "/web/v0/in/email/otp",
      state: "resend-state",
      button_label: "再送する",
      sent_message: "送信しました",
      too_soon_message: "しばらくお待ちください",
      failed_message: "失敗しました",
    },
    turnstile,
    form_errors: [],
    delivery_help: "届かない場合",
    back_link: backLink,
  };

  it("renders the one-time code field and the resend control", () => {
    const markup = renderToStaticMarkup(<EmailPassCodeForm {...props} />);

    expect(markup).toContain('name="client_email[pass_code]"');
    expect(markup).toContain('autoComplete="one-time-code"');
    expect(markup).toContain('maxLength="6"');
    expect(markup).toContain("再送する");
    expect(markup).toContain("届かない場合");
  });

  it("shows the attempt messages the server returned", () => {
    const markup = renderToStaticMarkup(
      <EmailPassCodeForm
        {...props}
        form_errors={["認証コードが違います"]}
      />,
    );

    expect(markup).toContain("認証コードが違います");
  });
});

describe("totp challenge form", () => {
  const props = {
    title: "二段階認証",
    description: "認証アプリのコード",
    form: {
      action: "/sign/in/challenge/totp",
      method: "post",
      token_field: {
        scope: "totp_challenge_form",
        field: "token",
        name: "totp_challenge_form[token]",
        label: "コード",
        placeholder: "6桁",
        max_length: 6,
        inputmode: "numeric" as const,
        help: "認証アプリを開いてください",
      },
      submit_label: "確認する",
    },
    error_heading: "入力を確認してください",
    form_errors: [],
    turnstile: { ...turnstile, mode: "execute" as const },
    back_link: backLink,
    cancel: { label: "キャンセル", action: "/sign/in/challenge", method: "delete" as const },
  };

  it("renders the code field without a delivered-code autocomplete", () => {
    const markup = renderToStaticMarkup(<TotpChallengeForm {...props} />);

    expect(markup).toContain('name="totp_challenge_form[token]"');
    expect(markup).not.toContain("one-time-code");
    expect(markup).toContain("認証アプリを開いてください");
  });

  it("renders an actor-scoped credential selector without database identifiers", () => {
    const markup = renderToStaticMarkup(
      <TotpChallengeForm
        {...props}
        form={{
          ...props.form,
          credential_selector: {
            name: "totp_challenge_form[credential_public_id]",
            field: "credential_public_id",
            scope: "totp_challenge_form",
            label: "認証アプリ",
            options: [
              { value: "client-totp-a", label: "仕事用" },
              { value: "client-totp-b", label: "個人用" },
            ],
          },
        }}
      />,
    );

    expect(markup).toContain('name="totp_challenge_form[credential_public_id]"');
    expect(markup).toContain('value="client-totp-a"');
    expect(markup).toContain('value="client-totp-b"');
    expect(markup).not.toContain('name="totp_challenge_form[credential_id]"');
  });

  // Back steps to method selection (a link); Cancel ends the ceremony (a DELETE form).
  it("keeps back to method selection separate from cancelling the ceremony", () => {
    const markup = renderToStaticMarkup(<TotpChallengeForm {...props} />);

    expect(markup).toContain(`href="${backLink.href}"`);
    expect(markup).toMatch(/<form[^>]*action="\/sign\/in\/challenge" method="post"/u);
    expect(markup).toContain('name="_method" value="delete"');
  });

  it("shows the verification failure the server returned", () => {
    const markup = renderToStaticMarkup(
      <TotpChallengeForm
        {...props}
        form_errors={["確認に失敗しました"]}
      />,
    );

    expect(markup).toContain("確認に失敗しました");
  });
});

describe("passkey sign-in screen", () => {
  it("renders a discoverable passkey ceremony without an identifier field", () => {
    const markup = renderToStaticMarkup(
      <PasskeySignInScreen
        title="パスキーでログイン"
        description="登録済みのパスキー"
        panel={{
          options_url: "/sign/in/passkey/options?ri=jp",
          verification_url: "/sign/in/passkey/verification?ri=jp",
          region: "jp",
          identifier_param: null,
          turnstile_site_key: "stealth-key",
          turnstile_error_message: "検証に失敗しました",
          field: null,
          submit_label: "パスキーでログイン",
        }}
        back_link={backLink}
      />,
    );

    expect(markup).not.toContain("identifier");
    expect(markup).not.toContain("メールアドレス");
    expect(markup).toContain("パスキーでログイン");
    expect(markup).toContain('href="/sign/in?ri=jp"');
  });
});

describe("step-up passkey screen", () => {
  it("posts the assertion natively to the endpoint the server named", () => {
    const markup = renderToStaticMarkup(
      <StepUpPasskeyScreen
        title="パスキーで確認"
        description="登録済みのパスキー"
        form={{
          action: "/sign/in/challenge/passkey",
          authenticity_token: "csrf-value",
          param_scope: "mfa_passkey_form",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "認証する",
        }}
        back_link={backLink}
        cancel={{ label: "キャンセル", action: "/sign/in/challenge", method: "delete" }}
      />,
    );

    expect(markup).toContain('action="/sign/in/challenge/passkey"');
    expect(markup).toContain('name="mfa_passkey_form[challenge_id]"');
    expect(markup).toContain('name="mfa_passkey_form[credential_json]"');
    expect(markup).toContain('name="authenticity_token"');
  });
});
