import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

// The step-up verification screens are pure renderers: every label and every URL is decided by the
// server, and no token, code or destination is ever among their props. These tests assert the
// markup the ERB templates used to produce, including the hidden fields the document forms submit.
import EmailOtpEntry from "@/features/auth/verification/EmailOtpEntry";
import EmailOtpRequest from "@/features/auth/verification/EmailOtpRequest";
import PasskeyVerification from "@/features/auth/verification/PasskeyVerification";
import TotpEntry from "@/features/auth/verification/TotpEntry";
import VerificationEntry from "@/features/auth/verification/VerificationEntry";
import VerificationSetup from "@/features/auth/verification/VerificationSetup";
import AppEmailsEdit from "@/pages/auth/app/verification/emails/edit";
import AppEmailsNew from "@/pages/auth/app/verification/emails/new";
import AppPasskeysNew from "@/pages/auth/app/verification/passkeys/new";
import AppSetupsNew from "@/pages/auth/app/verification/setups/new";
import AppTotpsNew from "@/pages/auth/app/verification/totps/new";
import AppVerificationsShow from "@/pages/auth/app/verifications/show";

const STEP_UP_CANCEL = {
  label: "キャンセル",
  action: "/verification/cancellation?ri=jp",
  method: "post" as const,
};

const back = { label: "戻る", href: "/verification?ri=jp" };

describe("verification entry screen", () => {
  const props = {
    cancel: STEP_UP_CANCEL,
    title: "検証",
    heading: "検証",
    section_title: "方法の選択",
    description: "続行するには検証が必要です。",
    methods: [
      { key: "passkey", label: "パスキー", href: "/verification/passkey/new?ri=jp" },
      { key: "email_otp", label: "メール", href: "/verification/email/new?ri=jp" },
    ],
    no_methods_notice: null,
    notice: null,
  };

  it("renders one link per available method", () => {
    const html = renderToStaticMarkup(<VerificationEntry {...props} />);

    expect(html).toContain('href="/verification/passkey/new?ri=jp"');
    expect(html).toContain('href="/verification/email/new?ri=jp"');
    expect(html).toContain("方法の選択");
  });

  // Cancelling ends the Step-Up ceremony on the server: a POST form, never a link or history step.
  it("offers cancellation as a POST to the cancellation endpoint", () => {
    const html = renderToStaticMarkup(<VerificationEntry {...props} />);

    expect(html).toMatch(/<form[^>]*action="\/verification\/cancellation\?ri=jp" method="post"/u);
    expect(html).not.toContain('name="_method"');
    expect(html).not.toContain('href="/verification/cancellation');
  });

  it("shows the notice instead of the methods when none is registered", () => {
    const html = renderToStaticMarkup(
      <VerificationEntry
        {...props}
        methods={[]}
        no_methods_notice="email/passkey/totp を登録してください"
        notice="再認証が完了しました"
      />,
    );

    expect(html).toContain("email/passkey/totp を登録してください");
    expect(html).toContain("再認証が完了しました");
    expect(html).not.toContain('href="/verification/passkey/new?ri=jp"');
  });

  it("is the component the auth/app page resolves", () => {
    expect(AppVerificationsShow).toBe(VerificationEntry);
  });
});

describe("verification setup screen", () => {
  const props = {
    title: "認証方法の登録",
    heading: "認証方法の登録",
    description: "続行する前に登録してください。",
    cancel: STEP_UP_CANCEL,
    methods: [{ key: "passkey", label: "パスキーを登録", href: "/settings/passkey/new?ri=jp" }],
  };

  // The success continuation is not a Back; cancelling the ceremony is the only exit.
  it("lists the missing methods and offers cancellation, not a way back", () => {
    const html = renderToStaticMarkup(<VerificationSetup {...props} />);

    expect(html).toContain('href="/settings/passkey/new?ri=jp"');
    expect(html).toMatch(/<form[^>]*action="\/verification\/cancellation\?ri=jp" method="post"/u);
    expect(html).not.toContain('href="/settings?ri=jp"');
  });

  it("is the component the auth/app page resolves", () => {
    expect(AppSetupsNew).toBe(VerificationSetup);
  });
});

describe("email one-time code request screen", () => {
  const props = {
    cancel: STEP_UP_CANCEL,
    title: "検証",
    heading: "検証",
    description: "方法を選択してください。",
    errors: [],
    form: {
      action: "/verification/emails?ri=jp",
      csrf_token: "csrf-token",
      scope: "settings_email",
      pt: "pt-value",
      submit_label: "メール（ワンタイムコード）",
    },
    back,
  };

  it("posts the ceremony context back as hidden fields", () => {
    const html = renderToStaticMarkup(<EmailOtpRequest {...props} />);

    expect(html).toContain('action="/verification/emails?ri=jp"');
    expect(html).toContain('name="authenticity_token" value="csrf-token"');
    expect(html).toContain('name="verification[scope]" value="settings_email"');
    expect(html).toContain('name="verification[pt]" value="pt-value"');
    expect(html).not.toContain('role="alert"');
  });

  it("renders the failure the server reported", () => {
    const html = renderToStaticMarkup(
      <EmailOtpRequest
        {...props}
        errors={["メールアドレスが未確認です"]}
        form={{ ...props.form, scope: null, pt: null }}
      />,
    );

    expect(html).toContain("メールアドレスが未確認です");
    expect(html).toContain('name="verification[scope]" value=""');
  });

  it("is the component the auth/app page resolves", () => {
    expect(AppEmailsNew).toBe(EmailOtpRequest);
  });
});

describe("email one-time code entry screen", () => {
  const props = {
    cancel: STEP_UP_CANCEL,
    title: "認証コード入力",
    heading: "認証コード入力",
    description: "入力いただいたメールアドレスに届きます。",
    delivery_help: "※1分以上待っても届かない場合",
    errors: ["確認コードが正しくありません"],
    form: {
      action: "/verification/emails/nonce?ri=jp",
      csrf_token: "csrf-token",
      scope: "settings_email",
      pt: "pt-value",
      code_label: "認証コード",
      code_placeholder: "6桁の数字を入力",
      submit_label: "送信する",
    },
    resend: {
      action: "/verification/emails/nonce/redelivery?ri=jp",
      csrf_token: "csrf-token",
      label: "再送する",
    },
    back,
  };

  it("submits the code as a document PATCH and offers redelivery", () => {
    const html = renderToStaticMarkup(<EmailOtpEntry {...props} />);

    expect(html).toContain('name="_method" value="patch"');
    expect(html).toContain('name="verification[code]"');
    expect(html).toContain("one-time-code");
    expect(html).toContain('action="/verification/emails/nonce/redelivery?ri=jp"');
    expect(html).toContain("確認コードが正しくありません");
    expect(html).toContain("戻る");
  });

  it("is the component the auth/app page resolves", () => {
    expect(AppEmailsEdit).toBe(EmailOtpEntry);
  });
});

describe("authenticator code entry screen", () => {
  const props = {
    cancel: STEP_UP_CANCEL,
    title: "認証コード入力",
    heading: "認証コード入力",
    description: "認証アプリに表示される6桁の認証コードを入力してください。",
    totp_help: "※認証コードは一定時間ごとに更新されます。",
    errors: [],
    form: {
      action: "/verification/totp?ri=jp",
      csrf_token: "csrf-token",
      scope: "settings_totp",
      pt: "pt-value",
      code_label: "認証コード",
      code_placeholder: "6桁の数字を入力",
      submit_label: "送信する",
    },
    turnstile: { site_key: "site-key", mode: "execute" as const, action: null, cdata: null },
    back,
  };

  it("renders the stealth challenge field alongside the code field", () => {
    const html = renderToStaticMarkup(<TotpEntry {...props} />);

    expect(html).toContain('name="cf-turnstile-response"');
    expect(html).toContain('name="verification[code]"');
    expect(html).not.toContain("one-time-code");
    expect(html).toContain("※認証コードは一定時間ごとに更新されます。");
  });

  it("renders the actor-scoped credential selector with public identifiers", () => {
    const html = renderToStaticMarkup(
      <TotpEntry
        {...props}
        form={{
          ...props.form,
          credential_selector: {
            name: "verification[credential_public_id]",
            label: "認証アプリ",
            options: [
              { value: "client-totp-a", label: "仕事用" },
              { value: "client-totp-b", label: "個人用" },
            ],
          },
        }}
      />,
    );

    expect(html).toContain('name="verification[credential_public_id]"');
    expect(html).toContain('value="client-totp-a"');
    expect(html).toContain('value="client-totp-b"');
    expect(html).not.toContain('name="verification[credential_id]"');
  });

  it("is the component the auth/app page resolves", () => {
    expect(AppTotpsNew).toBe(TotpEntry);
  });
});

describe("passkey verification screen", () => {
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
    back,
  };

  it("carries the challenge id and an empty credential field", () => {
    const html = renderToStaticMarkup(<PasskeyVerification {...props} />);

    expect(html).toContain('name="verification[challenge_id]" value="challenge-1"');
    expect(html).toContain('name="verification[credential_json]" value=""');
    expect(html).toContain("パスキーで認証");
  });

  it("renders the no-passkey failure the server reported", () => {
    const html = renderToStaticMarkup(
      <PasskeyVerification
        {...props}
        errors={["パスキーが登録されていません。"]}
      />,
    );

    expect(html).toContain("パスキーが登録されていません。");
  });

  it("is the component the auth/app page resolves", () => {
    expect(AppPasskeysNew).toBe(PasskeyVerification);
  });
});
