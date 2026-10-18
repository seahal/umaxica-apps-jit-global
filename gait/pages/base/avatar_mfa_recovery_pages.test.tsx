import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// Avatar, MFA reset and recovery-secret screens on the base surfaces. `Link` is stubbed to
// the anchor it produces so the static markup stays assertable outside a booted Inertia application.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

const { default: OrgAvatarShow } = await import("@/pages/base/org/avatars/show");
const { default: OrgMfaResetShow } = await import("@/pages/base/org/identity/mfa/resets/show");
const { default: ComMfaResetShow } = await import("@/pages/base/com/identity/mfa/resets/show");
const { default: AppRecoverySecretShow } =
  await import("@/pages/base/app/identity/recovery_secrets/show");

describe("base/org AvatarShow", () => {
  it("shows the moniker and the action link when the avatar exists", () => {
    const html = renderToStaticMarkup(
      <OrgAvatarShow
        title="Avatar"
        avatar={{ moniker: "Operator" }}
        empty_message={null}
        action_link={{ label: "Edit", href: "/avatar/edit" }}
        switcher_link={{ label: "Switch", href: "/switcher" }}
        up_link={{ label: "Dashboard", href: "/dashboard" }}
      />,
    );

    expect(html).toContain("Operator");
    expect(html).toContain('href="/avatar/edit"');
    expect(html).not.toContain('href="/switcher"');
  });

  it("falls back to the switcher when the server withheld the action link", () => {
    const html = renderToStaticMarkup(
      <OrgAvatarShow
        title="Avatar"
        avatar={{ moniker: "Operator" }}
        empty_message={null}
        action_link={null}
        switcher_link={{ label: "Switch", href: "/switcher" }}
        up_link={{ label: "Dashboard", href: "/dashboard" }}
      />,
    );

    expect(html).toContain('href="/switcher"');
    expect(html).not.toContain('href="/avatar/edit"');
  });

  it("shows the empty message and the switcher when no avatar is selected", () => {
    const html = renderToStaticMarkup(
      <OrgAvatarShow
        title="Avatar"
        avatar={null}
        empty_message="No avatar is selected."
        action_link={{ label: "Edit", href: "/avatar/edit" }}
        switcher_link={{ label: "Switch", href: "/switcher" }}
        up_link={{ label: "Dashboard", href: "/dashboard" }}
      />,
    );

    expect(html).toContain("No avatar is selected.");
    expect(html).toContain('href="/switcher"');
    expect(html).not.toContain('href="/avatar/edit"');
  });

  it("renders without a description when neither an avatar nor an empty message is sent", () => {
    const html = renderToStaticMarkup(
      <OrgAvatarShow
        title="Avatar"
        avatar={null}
        empty_message={null}
        action_link={null}
        switcher_link={{ label: "Switch", href: "/switcher" }}
        up_link={{ label: "Dashboard", href: "/dashboard" }}
      />,
    );

    expect(html).toContain("Avatar");
    expect(html).toContain('href="/switcher"');
  });
});

describe("base/org and base/com MfaResetShow", () => {
  it("explains on base/org that the reset is unavailable and links back", () => {
    const html = renderToStaticMarkup(
      <OrgMfaResetShow
        title="Multi factor reset"
        reset_unavailable="Reset is unavailable."
        back_link={{ label: "Back", href: "/identity" }}
      />,
    );

    expect(html).toContain("Multi factor reset");
    expect(html).toContain("Reset is unavailable.");
    expect(html).toContain('href="/identity"');
  });

  it("explains on base/com that the reset is unavailable and links back", () => {
    const html = renderToStaticMarkup(
      <ComMfaResetShow
        title="Multi factor reset"
        reset_unavailable="Reset is unavailable."
        back_link={{ label: "Back", href: "/identity" }}
      />,
    );

    expect(html).toContain("Multi factor reset");
    expect(html).toContain("Reset is unavailable.");
    expect(html).toContain('href="/identity"');
  });
});

describe("base/app recovery secret reveal", () => {
  const base = {
    title: "Recovery codes",
    description: "Keep them safe.",
    one_time_notice: "Shown once.",
    inventory_notice: "Ten codes.",
    missing_message: "Nothing to show.",
    back_link: { label: "Back", href: "https://example.test/identity" },
  };

  it("lists the revealed passcodes once", () => {
    const html = renderToStaticMarkup(
      <AppRecoverySecretShow
        {...base}
        passcodes={["aaa-bbb", "ccc-ddd"]}
      />,
    );

    expect(html).toContain("aaa-bbb");
    expect(html).toContain("ccc-ddd");
    expect(html).toContain("Shown once.");
    expect(html).not.toContain("Nothing to show.");
    expect(html).toContain('href="https://example.test/identity"');
  });

  it("explains that the reveal is gone when no passcode remains", () => {
    const html = renderToStaticMarkup(
      <AppRecoverySecretShow
        {...base}
        passcodes={[]}
      />,
    );

    expect(html).toContain("Nothing to show.");
    expect(html).not.toContain("<ul");
  });
});
