import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

import SignUpMethodChoice from "@/features/auth/signup/SignUpMethodChoice";
import SocialProviderButton from "@/features/auth/signup/SocialProviderButton";
import SocialSignUpConfirmation from "@/features/auth/signup/SocialSignUpConfirmation";

beforeEach(() => {
  document.head.innerHTML = '<meta name="csrf-token" content="csrf-value">';
});

afterEach(() => {
  document.head.innerHTML = "";
});

describe("SignUpMethodChoice", () => {
  const props = {
    title: "登録",
    suspended_notice: null as string | null,
    methods: [{ key: "email", label: "メールで登録", href: "/sign/up/email" }],
    social_providers: [
      { provider: "google", label: "Googleで登録", url: "/social/google" },
      {
        provider: "apple",
        label: "Appleで続行",
        url: "/social/apple",
        apple_logos: {
          white: "/images/social/apple_logo_white.svg",
          black: "/images/social/apple_logo_black.svg",
        },
      },
      { provider: "entra", label: "Entraで続行", url: "/social/entra" },
    ],
    links: [{ key: "sign_in", label: "ログイン", href: "/sign/in" }],
  };

  it("appends Cancel as plain text after the sign-in link", () => {
    const markup = renderToStaticMarkup(
      <SignUpMethodChoice
        {...props}
        cancel_label="Cancel"
      />,
    );
    const document = new DOMParser().parseFromString(markup, "text/html");
    const cancel = document.querySelector("section")?.lastElementChild;
    expect(cancel?.textContent).toBe("Cancel");
    expect(cancel?.tagName).toBe("P");
    expect(cancel?.closest("a, button, form")).toBeNull();
    expect(cancel?.querySelector("a, button, form")).toBeNull();
    expect(cancel?.previousElementSibling?.querySelector("a")?.getAttribute("href")).toBe(
      "/sign/in",
    );
  });

  it("omits Cancel when its optional label is absent", () => {
    const markup = renderToStaticMarkup(<SignUpMethodChoice {...props} />);
    expect(markup).not.toContain("Cancel");
  });

  it("lists every registration method and social provider the server offered", () => {
    const markup = renderToStaticMarkup(<SignUpMethodChoice {...props} />);

    expect(markup).toContain("登録");
    expect(markup).toContain('href="/sign/up/email"');
    expect(markup).toContain("Sign in with Google");
    expect(markup).toContain("/images/social/apple_logo_white.svg");
    expect(markup).toContain('value="Entraで続行"');
    expect(markup).toContain('href="/sign/in"');
  });

  it("shows the suspension notice instead of any entry point", () => {
    const markup = renderToStaticMarkup(
      <SignUpMethodChoice
        {...props}
        suspended_notice="現在受け付けていません"
      />,
    );

    expect(markup).toContain("現在受け付けていません");
    expect(markup).not.toContain('href="/sign/up/email"');
    expect(markup).not.toContain("Sign in with Google");
  });
});

describe("signup SocialProviderButton", () => {
  it("renders Apple without logos when the artwork is absent", () => {
    const markup = renderToStaticMarkup(
      <SocialProviderButton
        provider="apple"
        url="/social/apple"
        label="Appleで続行"
        apple_logos={null}
      />,
    );

    expect(markup).toContain("Appleで続行");
    expect(markup).not.toContain("apple_logo");
    expect(markup).toContain('name="authenticity_token"');
    expect(markup).toContain("csrf-value");
  });
});

describe("SocialSignUpConfirmation", () => {
  it("confirms a new identity and offers cancellation", () => {
    const markup = renderToStaticMarkup(
      <SocialSignUpConfirmation
        title="確認"
        unregistered="未登録です"
        create_identity="新しいアカウントを作ります"
        no_merge="既存アカウントには結びつきません"
        cancel_if_wrong="違う場合はキャンセル"
        confirm_label="作成に同意する"
        submit_label="続ける"
        cancel_label="キャンセル"
        action="/sign/up/check/social"
        checkpoint_version={2}
        turnstile={{ site_key: "site-key" }}
      />,
    );

    expect(markup).toContain("未登録です");
    expect(markup).toContain('name="_method" value="patch"');
    expect(markup).toContain('name="_method" value="delete"');
    expect(markup).toContain("作成に同意する");
  });
});
