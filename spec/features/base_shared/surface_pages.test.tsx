import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The base/app and base/com dashboard, identity, welcome, standing and sign-out screens left the
// shared ERB templates under `app/views/base/shared`. `Link` is stubbed to the anchor it produces
// so the static markup stays assertable outside a booted Inertia application.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

const { default: CredentialWarning } = await import("@/features/identity/CredentialWarning");
const { default: SurfaceDashboard } = await import("@/features/auth/SurfaceDashboard");
const { default: WelcomeShow } = await import("@/features/self_service/WelcomeShow");
const { default: StandingShow } = await import("@/features/identity/StandingShow");
const { default: SignOutConfirmation } = await import("@/features/sign_out/SignOutConfirmation");
const { default: Lobby } = await import("@/features/lobby/Lobby");

const { default: AppDashboardShow } = await import("@/pages/base/app/dashboards/show");
const { default: AppIdentityShow } = await import("@/pages/base/app/identities/show");
const { default: AppWelcomeShow } = await import("@/pages/base/app/welcomes/show");
const { default: AppStandingShow } = await import("@/pages/base/app/identity/standings/show");
const { default: AppSignOutEdit } = await import("@/pages/base/app/sign_outs/edit");
const { default: AppLobbyShow } = await import("@/pages/base/app/lobbies/show");
const { default: AppOidcLogoutShow } = await import("@/pages/base/app/oidc/logouts/show");

const { default: ComDashboardShow } = await import("@/pages/base/com/dashboards/show");
const { default: ComIdentityShow } = await import("@/pages/base/com/identities/show");
const { default: ComWelcomeShow } = await import("@/pages/base/com/welcomes/show");
const { default: ComStandingShow } = await import("@/pages/base/com/identity/standings/show");
const { default: ComSignOutEdit } = await import("@/pages/base/com/sign_outs/edit");
const { default: ComLobbyShow } = await import("@/pages/base/com/lobbies/show");
const { default: ComOidcLogoutShow } = await import("@/pages/base/com/oidc/logouts/show");

const warning = {
  heading: "Add another sign-in method",
  body: "Adding another sign-in method helps you access your account if Apple sign-in is unavailable.",
  items: [
    { label: "Add a passkey", href: "https://auth.example/settings/passkey/new?ri=jp" },
    { label: "Link Google", href: "https://auth.example/settings/google/edit?ri=jp" },
  ],
};

describe("CredentialWarning", () => {
  it("labels the region and links every alternative the server sent", () => {
    const markup = renderToStaticMarkup(<CredentialWarning {...warning} />);

    expect(markup).toContain('id="apple-only-credential-warning"');
    expect(markup).toContain("Add another sign-in method");
    expect(markup).toContain('href="https://auth.example/settings/passkey/new?ri=jp"');
    expect(markup).toContain("Link Google");
  });
});

describe("SurfaceDashboard credential warning", () => {
  const props = {
    title: "Identity",
    description: "Signed in",
    sections: [{ heading: "Account", items: [{ label: "Logout", href: "/sign/out/new" }] }],
  };

  it("shows the warning only when the server sent one", () => {
    expect(renderToStaticMarkup(<SurfaceDashboard {...props} />)).not.toContain(
      "apple-only-credential-warning",
    );
    expect(
      renderToStaticMarkup(
        <SurfaceDashboard
          {...props}
          credential_warning={warning}
        />,
      ),
    ).toContain("apple-only-credential-warning");
  });
});

describe("WelcomeShow credential warning", () => {
  const props = { title: "Welcome!", next_link: { label: "Next", href: "/dashboard?ri=jp" } };

  it("shows the warning only when the server sent one", () => {
    const plain = renderToStaticMarkup(<WelcomeShow {...props} />);

    expect(plain).toContain('href="/dashboard?ri=jp"');
    expect(plain).not.toContain("apple-only-credential-warning");

    expect(
      renderToStaticMarkup(
        <WelcomeShow
          {...props}
          credential_warning={warning}
        />,
      ),
    ).toContain("apple-only-credential-warning");
  });
});

describe("SignOutConfirmation", () => {
  it("posts the logout challenge the server issued", () => {
    const markup = renderToStaticMarkup(
      <SignOutConfirmation
        title="Sign out"
        active
        description="You will need to sign in again."
        form={{
          action: "/sign/out",
          submit: "Sign out",
          logout_challenge: "challenge-value",
          confirm_description: "Ends this session.",
        }}
        home_link={{ label: "Home", href: "/" }}
      />,
    );

    expect(markup).toContain('name="logout_challenge"');
    expect(markup).toContain("challenge-value");
  });

  it("omits the challenge field when the server sent none", () => {
    const markup = renderToStaticMarkup(
      <SignOutConfirmation
        title="Sign out"
        active
        description="You will need to sign in again."
        form={{
          action: "/sign/out",
          submit: "Sign out",
          logout_challenge: null,
          confirm_description: "Ends this session.",
        }}
        home_link={{ label: "Home", href: "/" }}
      />,
    );

    expect(markup).not.toContain("logout_challenge");
  });
});

describe("Lobby", () => {
  it("offers sign in and shows a one-shot sign-out notice when the server sent one", () => {
    const markup = renderToStaticMarkup(
      <Lobby
        title="Lobby"
        heading="Lobby"
        description="Sign in to continue."
        sign_in={{ label: "Sign in", href: "/oidc/authorization?screen_hint=signin" }}
        notice={{ title: "You are signed out", description: "Access ends soon." }}
      />,
    );

    expect(markup).toContain("You are signed out");
    expect(markup).toContain("Access ends soon.");
    expect(markup).toContain('href="/oidc/authorization?screen_hint=signin"');
    expect(markup).toContain("<output");
  });
});

describe("base/app and base/com page modules", () => {
  it("re-export the shared components for their own surface", () => {
    expect(AppDashboardShow).toBe(SurfaceDashboard);
    expect(AppIdentityShow).toBe(SurfaceDashboard);
    expect(AppWelcomeShow).toBe(WelcomeShow);
    expect(AppStandingShow).toBe(StandingShow);
    expect(AppSignOutEdit).toBe(SignOutConfirmation);
    expect(AppLobbyShow).toBe(Lobby);
    expect(AppOidcLogoutShow).toBe(SignOutConfirmation);

    expect(ComDashboardShow).toBe(SurfaceDashboard);
    expect(ComIdentityShow).toBe(SurfaceDashboard);
    expect(ComWelcomeShow).toBe(WelcomeShow);
    expect(ComStandingShow).toBe(StandingShow);
    expect(ComSignOutEdit).toBe(SignOutConfirmation);
    expect(ComLobbyShow).toBe(Lobby);
    expect(ComOidcLogoutShow).toBe(SignOutConfirmation);
  });
});
