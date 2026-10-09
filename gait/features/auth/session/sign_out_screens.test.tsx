import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The sign-out pages are rendered without mounting here, so `useForm` only has to answer with the
// shape the components read. The interaction spec mounts them for the handler branches.
vi.mock("@inertiajs/react", () => ({
  useForm: () => ({
    processing: false,
    post: vi.fn(),
    delete: vi.fn(),
    transform: vi.fn(),
  }),
}));

const { default: SignOutConfirmation } =
  await import("@/features/auth/session/SignOutConfirmation");
const { default: SignOutCompleted } = await import("@/features/auth/session/SignOutCompleted");
const { default: SignOutUnavailable } = await import("@/features/auth/session/SignOutUnavailable");
const { default: AuthAppSignOutEdit } = await import("@/pages/auth/app/sign/outs/edit");
const { default: AuthAppSignOutComplete } = await import("@/pages/auth/app/sign/outs/complete");
const { default: AuthAppSignOutUnavailable } =
  await import("@/pages/auth/app/sign/outs/unavailable");

const confirmationProps = {
  title: "ログアウトしますか？",
  heading: "ログアウトしますか？",
  active_context: true,
  confirm_description: "一度ログアウトすると、再度ログインが必要になります。",
  already_signed_out: "すでにサインアウトしています。",
  submit_label: "ログアウトします",
  form: { action: "/sign/out?ri=jp", logout_challenge: null },
  cancel: { label: "キャンセル", action: "/sign/out?ri=jp" },
  home_link: { label: "ホームへ戻る", href: "/?ri=jp" },
};

describe("SignOutConfirmation", () => {
  it("keeps the cancellation a DELETE to the sign-out route", () => {
    const markup = renderToStaticMarkup(<SignOutConfirmation {...confirmationProps} />);

    expect(markup).toContain('<input type="hidden" name="_method" value="delete"/>');
    expect(markup).toContain('action="/sign/out?ri=jp" method="post"');
    expect(markup).toContain("ログアウトします");
    expect(markup).toContain("一度ログアウトすると、再度ログインが必要になります。");
  });

  it("offers no sign-out form when there is nothing left to clear", () => {
    const markup = renderToStaticMarkup(
      <SignOutConfirmation
        {...confirmationProps}
        active_context={false}
      />,
    );

    expect(markup).not.toContain("<form");
    expect(markup).toContain("すでにサインアウトしています。");
  });

  it("links home with the destination the server generated", () => {
    expect(renderToStaticMarkup(<SignOutConfirmation {...confirmationProps} />)).toMatch(
      /<a href="\/\?ri=jp"[^>]*>ホームへ戻る<\/a>/u,
    );
  });
});

describe("SignOutCompleted", () => {
  const props = {
    title: "サインアウトしました",
    heading: "サインアウトしました",
    description: "2026-01-01 09:00以降には確実にアクセスが不可能となります。",
    home_link: { label: "ホームへ戻る", href: "/?ri=jp" },
  };

  it("shows the expiry the server resolved", () => {
    expect(renderToStaticMarkup(<SignOutCompleted {...props} />)).toContain(
      "2026-01-01 09:00以降には確実にアクセスが不可能となります。",
    );
  });

  it("omits the description when the server could not resolve an expiry", () => {
    const markup = renderToStaticMarkup(
      <SignOutCompleted
        {...props}
        description={null}
      />,
    );

    expect(markup).not.toContain("以降には確実に");
    expect(markup).toContain("サインアウトしました");
  });
});

describe("SignOutUnavailable", () => {
  const props = {
    title: "ログアウトできません",
    heading: "ログアウトできません",
    description: "もう一度お試しください。",
    retry: { label: "再試行", action: "/sign/out?ri=jp" },
    home_link: { label: "ホームへ戻る", href: "/?ri=jp" },
  };

  it("retries with a POST rather than a link", () => {
    const markup = renderToStaticMarkup(<SignOutUnavailable {...props} />);

    expect(markup).toContain('<form action="/sign/out?ri=jp" method="post">');
    expect(markup).toContain("再試行");
    expect(markup).toContain("もう一度お試しください。");
  });
});

describe("auth/app sign-out pages", () => {
  it.each([
    ["edit", AuthAppSignOutEdit, SignOutConfirmation],
    ["complete", AuthAppSignOutComplete, SignOutCompleted],
    ["unavailable", AuthAppSignOutUnavailable, SignOutUnavailable],
  ])("%s re-exports the shared component", (_action, Page, Component) => {
    expect(Page).toBe(Component);
  });
});
