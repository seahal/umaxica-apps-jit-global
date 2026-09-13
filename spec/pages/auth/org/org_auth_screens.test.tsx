// The operator-facing auth screens, rendered with the shapes the server actually sends.
//
// Each one is a decision the server already made -- a suspended sign-up, an unavailable provider, a
// step-up with no configured method -- so the page is asserted in both the present and the absent
// shape of every prop the server may omit. A page that quietly rendered a form the server withheld
// would offer a ceremony the request phase refuses.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { TurnstileApi } from "@/lib/turnstile";
import OrgEntraSettingsEdit from "@/pages/auth/org/settings/entras/edit";
import OrgEntraSettingsShow from "@/pages/auth/org/settings/entras/show";
import OrgPasskeySettingsEdit from "@/pages/auth/org/settings/passkeys/edit";
import OrgPasskeySettingsNew from "@/pages/auth/org/settings/passkeys/new";
import OrgMfaPasskeyPage from "@/pages/auth/org/sign/in/challenge/passkeys/new";
import OrgEmergencyPasskeySignInPage from "@/pages/auth/org/sign/in/emergency/passkeys/new";
import OrgPasskeySignInPage from "@/pages/auth/org/sign/in/passkeys/new";
import OrgSecretSignInPage from "@/pages/auth/org/sign/in/secrets/new";
import OrgSignInEntry from "@/pages/auth/org/sign/ins/show";
import OrgInvitationPage from "@/pages/auth/org/sign/up/invitations/new";
import OrgSignUpEntry from "@/pages/auth/org/sign/ups/show";
import OrgEntraSessionEntry from "@/pages/auth/org/social/sessions/new";
import OrgVerificationPasskeyPage from "@/pages/auth/org/verification/passkeys/new";
import OrgVerificationSetup from "@/pages/auth/org/verification/setups/new";
import OrgVerificationEntry from "@/pages/auth/org/verifications/show";

import { mount } from "../../../support/react";

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

vi.mock("@/features/auth/passkeys/StepUpPasskeyForm", () => ({
  default: ({ submit_label: submitLabel }: { submit_label: string }) => (
    <button type="button">{submitLabel}</button>
  ),
}));

const BACK = { label: "戻る", href: "/org" };

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
  const api: TurnstileApi = { render: vi.fn(() => "widget-1"), execute: vi.fn(), remove: vi.fn() };
  window.turnstile = api;
});

afterEach(() => {
  document.head.innerHTML = "";
  delete window.turnstile;
});

describe("OrgSignUpEntry", () => {
  const props = {
    title: "運営メンバー登録",
    description: "登録は招待制です",
    suspended_notice: null,
    recruit: { prompt: "興味がありますか", label: "採用情報", href: "/careers" },
    sign_in_link: { label: "ログイン", href: "/org/sign/in" },
    back_to_root: BACK,
  };

  it("shows the suspension notice alone when sign-up is switched off", () => {
    const screen = mount(
      <OrgSignUpEntry
        {...props}
        suspended_notice="現在受け付けていません"
      />,
    );

    expect(screen.text("[data-test-id='sign-up-suspended']")).toBe("現在受け付けていません");
    expect(screen.container.querySelectorAll("a")).toHaveLength(0);
  });

  it("offers the recruiting route and the sign-in link", () => {
    const screen = mount(<OrgSignUpEntry {...props} />);
    const links = [...screen.container.querySelectorAll("a")].map((link) => link.textContent);

    expect(screen.text("h1")).toBe("運営メンバー登録");
    expect(links).toContain("採用情報");
    expect(links).toContain("ログイン");
  });

  it("renders without the optional description, links or recruiting block", () => {
    const screen = mount(
      <OrgSignUpEntry
        {...props}
        description={null}
        recruit={null}
        sign_in_link={null}
        back_to_root={null}
      />,
    );

    expect(screen.text("h1")).toBe("運営メンバー登録");
    expect(screen.container.querySelectorAll("a")).toHaveLength(0);
  });
});

describe("OrgSignInEntry", () => {
  const props = {
    title: "ログイン",
    description: "運営メンバー向け",
    methods: [
      { key: "entra", kind: "provider" as const, label: "Entra ID でログイン", href: "/org/entra" },
      { key: "secret", kind: "link" as const, label: "パスワードでログイン", href: "/org/secret" },
    ],
    registration_link: { label: "招待コードをお持ちの方", href: "/org/invitation" },
    back_to_root: BACK,
  };

  it("posts the provider method as a document form and links the rest", () => {
    const screen = mount(<OrgSignInEntry {...props} />);
    const form = screen.container.querySelector("form.social-provider-form");

    expect(form?.getAttribute("action")).toBe("/org/entra");
    expect(form?.getAttribute("method")).toBe("post");
    expect(
      screen.container.querySelector<HTMLInputElement>('input[name="authenticity_token"]')?.value,
    ).toBe("csrf-value");
    expect(
      screen.container.querySelector<HTMLInputElement>(".social-provider-button--entra")?.value,
    ).toBe("Entra ID でログイン");
    expect(screen.container.querySelector('a[href="/org/secret"]')?.textContent).toContain(
      "パスワードでログイン",
    );
  });

  it("omits the registration link when the server sends none", () => {
    const screen = mount(
      <OrgSignInEntry
        {...props}
        registration_link={null}
      />,
    );

    expect(screen.container.querySelector('a[href="/org/invitation"]')).toBeNull();
  });
});

describe("OrgEntraSessionEntry", () => {
  it("offers the ceremony as a document POST", () => {
    const screen = mount(
      <OrgEntraSessionEntry
        title="Entra ID でログイン"
        unavailable_notice={null}
        form={{ action: "/org/entra/session", submit_label: "続ける" }}
      />,
    );

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/entra/session",
    );
    expect(screen.container.querySelector<HTMLInputElement>(".btn-entra")?.value).toBe("続ける");
  });

  it("shows the notice and no form when the provider is switched off", () => {
    const screen = mount(
      <OrgEntraSessionEntry
        title="Entra ID でログイン"
        unavailable_notice="現在利用できません"
        form={null}
      />,
    );

    expect(screen.container.textContent).toContain("現在利用できません");
    expect(screen.container.querySelector("form")).toBeNull();
  });
});

describe("OrgEntraSettingsEdit", () => {
  const props = {
    title: "Entra ID",
    heading: "Entra ID 連携",
    back_link: BACK,
    connected: false,
    connected_notice: null,
    unavailable_notice: null,
    form: { action: "/org/settings/entra", submit_label: "連携する" },
  };

  it("offers the connect form when the server allows connecting", () => {
    const screen = mount(<OrgEntraSettingsEdit {...props} />);

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/settings/entra",
    );
    expect(screen.text("button")).toBe("連携する");
    expect(screen.container.textContent).not.toContain("Connected");
  });

  it("reports an existing connection with the server's own notice and no form", () => {
    const screen = mount(
      <OrgEntraSettingsEdit
        {...props}
        connected
        connected_notice="2026年8月に連携しました"
        form={null}
      />,
    );

    expect(screen.container.textContent).toContain("Connected");
    expect(screen.container.textContent).toContain("2026年8月に連携しました");
    expect(screen.container.querySelector("form")).toBeNull();
  });

  it("reports a connection without a notice, and an unavailable provider", () => {
    const screen = mount(
      <OrgEntraSettingsEdit
        {...props}
        connected
        form={null}
        unavailable_notice="この環境では利用できません"
      />,
    );

    expect(screen.container.textContent).toContain("Connected");
    expect(screen.container.textContent).toContain("この環境では利用できません");
  });
});

describe("OrgEntraSettingsShow", () => {
  it("shows the connection state and the route to change it", () => {
    const screen = mount(
      <OrgEntraSettingsShow
        title="Entra ID"
        heading="Entra ID 連携"
        back_link={BACK}
        status="未連携"
        edit_link={{ label: "連携を編集", href: "/org/settings/entra/edit" }}
      />,
    );

    expect(screen.container.textContent).toContain("未連携");
    expect(screen.container.querySelector('a[href="/org/settings/entra/edit"]')?.textContent).toBe(
      "連携を編集",
    );
  });
});

describe("OrgVerificationEntry", () => {
  const props = {
    title: "本人確認",
    section_title: "確認方法",
    section_description: "いずれかを選んでください",
    notice: null,
    no_methods: null,
    methods: [{ key: "passkey", label: "パスキー", href: "/org/verification/passkey" }],
  };

  it("lists every method the server offered", () => {
    const screen = mount(<OrgVerificationEntry {...props} />);

    expect(screen.container.querySelectorAll("li")).toHaveLength(1);
    expect(
      screen.container.querySelector('a[href="/org/verification/passkey"]')?.textContent,
    ).toContain("パスキー");
  });

  it("shows the notice and the empty-state text when no method is available", () => {
    const screen = mount(
      <OrgVerificationEntry
        {...props}
        notice="再度確認が必要です"
        no_methods="利用できる方法がありません"
        methods={[]}
      />,
    );

    expect(screen.container.textContent).toContain("再度確認が必要です");
    expect(screen.container.textContent).toContain("利用できる方法がありません");
    expect(screen.container.querySelectorAll("li")).toHaveLength(0);
  });
});

describe("OrgVerificationSetup", () => {
  it("lists the methods an operator may still configure", () => {
    const screen = mount(
      <OrgVerificationSetup
        title="確認方法の設定"
        description="まず方法を登録してください"
        back_link={BACK}
        methods={[{ key: "passkey", label: "パスキーを登録", href: "/org/settings/passkeys/new" }]}
      />,
    );

    expect(
      screen.container.querySelector('a[href="/org/settings/passkeys/new"]')?.textContent,
    ).toContain("パスキーを登録");
  });

  it("renders without an up link when the server sends none", () => {
    const screen = mount(
      <OrgVerificationSetup
        title="確認方法の設定"
        description="まず方法を登録してください"
        back_link={null}
        methods={[]}
      />,
    );

    expect(screen.text("h1")).toBe("確認方法の設定");
  });
});

const turnstile = {
  site_key: "site-key",
  mode: "render" as const,
  action: null,
  cdata: null,
};

describe("OrgSecretSignInPage", () => {
  it("posts the secret with the CSRF token, and asks for no identifier", () => {
    const screen = mount(
      <OrgSecretSignInPage
        title="パスワードでログイン"
        form_action="/org/sign/in/secret"
        hidden_fields={{ pt: "pending", ri: "jp" }}
        errors_title="入力を確認してください"
        errors={["認証に失敗しました"]}
        secret={{
          name: "staff_secret_credential_login_form[secret_credential_value]",
          label: "パスワード",
          placeholder: "••••",
        }}
        submit_label="送信する"
        back_link={BACK}
        turnstile={turnstile}
      />,
    );

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/sign/in/secret",
    );
    expect(
      screen.container.querySelector<HTMLInputElement>('input[name="authenticity_token"]')?.value,
    ).toBe("csrf-value");
    expect(screen.container.querySelector('input[name="pt"]')?.getAttribute("value")).toBe(
      "pending",
    );
    expect(screen.container.textContent).toContain("認証に失敗しました");
    // Entra ID already selected the operator; a submitted identifier could only
    // be an attempt to substitute a different one.
    expect(screen.container.querySelector('input[type="text"]')).toBeNull();
    expect(screen.container.textContent).not.toContain("ID");
  });

  it("omits the pending-token field when the server sent none", () => {
    const screen = mount(
      <OrgSecretSignInPage
        title="パスワードでログイン"
        form_action="/org/sign/in/secret"
        hidden_fields={{ pt: null, ri: "jp" }}
        errors_title="入力を確認してください"
        errors={[]}
        secret={{
          name: "staff_secret_credential_login_form[secret_credential_value]",
          label: "パスワード",
          placeholder: "••••",
        }}
        submit_label="送信する"
        back_link={BACK}
        turnstile={turnstile}
      />,
    );

    expect(screen.container.querySelector('input[name="pt"]')).toBeNull();
  });
});

describe("OrgInvitationPage", () => {
  it("posts the invitation code", () => {
    const screen = mount(
      <OrgInvitationPage
        title="招待コード"
        description="コードを入力してください"
        form_error="無効なコードです"
        form_action="/org/sign/up/invitation"
        invitation_code_label="招待コード"
        invitation_code=""
        submit_label="送信する"
        back_link={BACK}
        turnstile={turnstile}
      />,
    );

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/sign/up/invitation",
    );
    expect(screen.container.textContent).toContain("無効なコードです");
  });

  it("renders the invitation form with no inline error", () => {
    const screen = mount(
      <OrgInvitationPage
        title="招待コード"
        description="コードを入力してください"
        form_error={null}
        form_action="/org/sign/up/invitation"
        invitation_code_label="招待コード"
        invitation_code=""
        submit_label="送信する"
        back_link={BACK}
        turnstile={turnstile}
      />,
    );

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/sign/up/invitation",
    );
  });
});

describe("Org passkey ceremony pages", () => {
  const identifierField = {
    label: "ID",
    placeholder: "OP-1",
    min_length: 3,
    max_length: 32,
    pattern: "[A-Z0-9-]+",
  };

  // The normal ceremony is the second stage of Entra sign-in, so the panel has
  // no identifier: the server reads the operator from its pending transaction.
  const panel = {
    options_url: "/org/in/passkeys/options",
    verification_url: "/org/in/passkeys/verification",
    region: "jp",
    identifier_param: null,
    turnstile_site_key: "site-key",
    turnstile_error_message: "検証に失敗しました",
    field: null,
    submit_label: "パスキーでログイン",
  };

  // The panel itself is mocked here; that it renders no identifier field for a
  // null one is covered in spec/features/auth/passkeys/passkey_panels.test.tsx.
  it("renders operator passkey sign-in with an identifier-less panel and the secret fallback", () => {
    const screen = mount(
      <OrgPasskeySignInPage
        title="パスキー"
        description="登録済みのパスキー"
        panel={panel}
        secret_link={{ label: "シークレットを使う", href: "/org/sign/in/secret/new" }}
        back_link={BACK}
      />,
    );

    expect(screen.container.textContent).toContain("パスキーでログイン");
    expect(screen.container.querySelector('a[href="/org/sign/in/secret/new"]')?.textContent).toBe(
      "シークレットを使う",
    );
  });

  // Emergency Access has no earlier stage to name the operator, so it is
  // identifier-first, and it says up front what the resulting session cannot do.
  it("renders emergency access sign-in with an identifier field and a restricted-mode notice", () => {
    const screen = mount(
      <OrgEmergencyPasskeySignInPage
        title="緊急アクセス"
        description="登録済みのパスキー"
        restricted_mode_notice="制限モードのセッションになります"
        panel={{ ...panel, identifier_param: "identifier", field: identifierField }}
        back_link={BACK}
      />,
    );

    expect(screen.container.textContent).toContain("制限モードのセッションになります");
    expect(screen.container.textContent).toContain("パスキーでログイン");
  });

  it("renders the second-factor passkey form", () => {
    const screen = mount(
      <OrgMfaPasskeyPage
        title="パスキーで確認"
        description="登録済みのパスキー"
        form={{
          action: "/org/sign/in/challenge/passkey",
          param_scope: "mfa_passkey_form",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "認証する",
        }}
        back_link={BACK}
      />,
    );

    expect(screen.container.textContent).toContain("認証する");
  });

  it("renders passkey registration", () => {
    const screen = mount(
      <OrgPasskeySettingsNew
        title="パスキー登録"
        description="新しいパスキー"
        registration={{
          options_url: "/org/settings/passkeys",
          verification_url: "/org/settings/passkeys",
          description_label: "名前",
          description_placeholder: "MacBook",
          submit_label: "登録する",
          turnstile_site_key: "site-key",
          turnstile_error_message: "検証に失敗しました",
        }}
        cancel_link={BACK}
      />,
    );

    expect(screen.container.textContent).toContain("登録する");
  });

  it("renders passkey rename", () => {
    const screen = mount(
      <OrgPasskeySettingsEdit
        title="パスキーの名前"
        form_action="/org/settings/passkeys/pk_1"
        description_label="名前"
        description_value="MacBook"
        submit_label="更新"
        cancel_link={BACK}
        errors_title="入力を確認してください"
        errors={[]}
        turnstile={turnstile}
      />,
    );

    expect(screen.container.querySelector("form")?.getAttribute("action")).toBe(
      "/org/settings/passkeys/pk_1",
    );
  });

  it("renders the verification passkey challenge", () => {
    const screen = mount(
      <OrgVerificationPasskeyPage
        title="パスキーで確認"
        description="登録済みのパスキー"
        errors_sentence="失敗しました"
        form={{
          action: "/org/verification/passkey",
          param_scope: "verification",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "認証する",
        }}
        back_link={BACK}
      />,
    );

    expect(screen.container.textContent).toContain("失敗しました");
    expect(screen.container.textContent).toContain("認証する");
  });

  it("renders the verification passkey challenge with no inline error", () => {
    const screen = mount(
      <OrgVerificationPasskeyPage
        title="パスキーで確認"
        description="登録済みのパスキー"
        errors_sentence={null}
        form={{
          action: "/org/verification/passkey",
          param_scope: "verification",
          challenge_id: "challenge-1",
          request_options: { challenge: "abc" },
          submit_label: "認証する",
        }}
        back_link={BACK}
      />,
    );

    expect(screen.container.textContent).toContain("認証する");
  });
});
