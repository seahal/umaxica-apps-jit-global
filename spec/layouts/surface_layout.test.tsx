import { render as renderTree, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, test, vi } from "vitest";

import type { SurfaceChrome } from "@/types/inertia";

// The layout renders only what SurfaceChrome assembled on the server, so the page object is the
// single input. The chrome components have their own specs; here they are replaced by markers so
// the layout's own structure is what is asserted.
//
// The assertions query by role and accessible name rather than by markup. The layout's contract is
// its document structure — landmarks, headings, lists and link targets — and that has to survive
// the styling it carries, which exact-markup assertions did not.
vi.mock("@inertiajs/react", () => ({
  usePage: () => page,
}));

vi.mock("@/components/chrome/CookieBanner", () => ({
  default: ({ controls }: { controls: { title: string } }) => (
    <div data-testid="cookie-banner">{controls.title}</div>
  ),
}));

vi.mock("@/components/chrome/ThemeControls", () => ({
  default: ({ controls }: { controls: { title: string } }) => (
    <div data-testid="theme-controls">{controls.title}</div>
  ),
}));

const { default: SurfaceLayout } = await import("@/layouts/SurfaceLayout");

const cookieControls = {
  hidden: false,
  scope: "cookie",
  settings_url: "/preference/cookie/edit",
  title: "cookie-controls-title",
  description_html: "cookie description",
  close_button: "閉じる",
  reject_all: "すべて拒否",
  open_settings: "設定を開く",
  accept_all: "すべて許可",
};

const themeControls = {
  hidden: false,
  title: "theme-controls-title",
  description: "テーマを選びます。",
  options: { system: "システム", light: "ライト", dark: "ダーク" },
};

const minimalChrome: SurfaceChrome = {
  family_label: null,
  surface: "app",
  brand: { name: "Umaxica", href: "https://umaxica.app/" },
  banner: null,
  restricted_mode: null,
  footer_navigation: null,
  cookie_controls: cookieControls,
  theme_controls: themeControls,
  copyright: "(c) Umaxica",
};

const page = { props: { chrome: minimalChrome, errors: {} } };

const render = (chrome: SurfaceChrome) => {
  page.props.chrome = chrome;
  return renderTree(
    <SurfaceLayout>
      <p>page body</p>
    </SurfaceLayout>,
  );
};

afterEach(() => {
  page.props.chrome = minimalChrome;
});

describe("SurfaceLayout", () => {
  test("omits theme and cookie chrome when the server sent none", () => {
    render({
      ...minimalChrome,
      theme_controls: null,
      cookie_controls: null,
    });

    expect(screen.queryByTestId("theme-controls")).toBeNull();
    expect(screen.queryByTestId("cookie-banner")).toBeNull();
  });

  test("renders the page inside the main landmark", () => {
    render(minimalChrome);

    const main = screen.getByRole("main");
    expect(main.id).toBe("main");
    expect(within(main).getByText("page body")).toBeTruthy();
  });

  test("renders the brand, surface and copyright the server resolved", () => {
    const { container } = render(minimalChrome);

    expect(screen.getByRole("link", { name: "Umaxica" }).getAttribute("href")).toBe(
      "https://umaxica.app/",
    );
    expect(container.textContent).toContain("(app)");
    expect(container.textContent).toContain("(c) Umaxica");
  });

  test("renders the family label only when the surface carries one", () => {
    expect(render(minimalChrome).container.textContent).not.toContain("Base");
    expect(render({ ...minimalChrome, family_label: "Base" }).container.textContent).toContain(
      "Base",
    );
  });

  test("renders the chrome components with the controls the server assembled", () => {
    render(minimalChrome);

    expect(screen.getByTestId("cookie-banner").textContent).toBe("cookie-controls-title");
    expect(screen.getByTestId("theme-controls").textContent).toBe("theme-controls-title");
    expect(screen.getByRole("complementary", { name: "Preferences" })).toBeTruthy();
  });

  test("omits the banner and footer navigation when absent", () => {
    render(minimalChrome);

    expect(screen.queryByRole("region", { name: "banner" })).toBeNull();
    expect(screen.queryByRole("navigation", { name: "Footer" })).toBeNull();
    // The surface layout carries no primary/header navigation at all.
    expect(screen.queryByRole("navigation", { name: "Primary" })).toBeNull();
  });

  // Restricted Mode is session state, published once by the server and rendered here for the whole
  // life of the session. A page cannot supply it and therefore cannot drop it.
  test("renders no restricted mode indicator for an ordinary session", () => {
    render(minimalChrome);

    expect(screen.queryByRole("region", { name: "制限モード — Emergency Access" })).toBeNull();
  });

  test("renders the restricted mode indicator above everything else in the header", () => {
    render({
      ...minimalChrome,
      restricted_mode: {
        label: "制限モード — Emergency Access",
        description: "段階的認証は利用できません。",
        sign_out: { label: "サインアウトして通常モードでサインインし直す", href: "/sign/out/new" },
      },
    });

    const indicator = screen.getByRole("region", { name: "制限モード — Emergency Access" });
    expect(within(indicator).getByText("段階的認証は利用できません。")).toBeTruthy();

    // The only way back to a normal session is to end this one; there is no in-place switch.
    const signOut = within(indicator).getByRole("link", {
      name: "サインアウトして通常モードでサインインし直す",
    });
    expect(signOut.getAttribute("href")).toBe("/sign/out/new");
    expect(indicator.textContent).not.toContain("解除");
  });

  test("renders the banner with its title", () => {
    render({
      ...minimalChrome,
      banner: { title: "メンテナンス", body: "停止予定があります。" },
    });

    const banner = screen.getByRole("region", { name: "banner" });
    expect(within(banner).getByRole("heading", { name: "メンテナンス" })).toBeTruthy();
    expect(within(banner).getByText("停止予定があります。")).toBeTruthy();
  });

  test("renders a banner that carries no title without an empty heading", () => {
    render({ ...minimalChrome, banner: { title: null, body: "本文のみ" } });

    const banner = screen.getByRole("region", { name: "banner" });
    expect(within(banner).getByText("本文のみ")).toBeTruthy();
    expect(within(banner).queryByRole("heading")).toBeNull();
  });

  // Footer navigation targets cross hosts, so the links stay document visits rather than Inertia
  // visits.
  test("renders footer navigation links as plain anchors", () => {
    render({
      ...minimalChrome,
      footer_navigation: [{ label: "会社概要", href: "https://umaxica.com/about" }],
    });

    const footer = screen.getByRole("navigation", { name: "Footer" });
    const about = within(footer).getByRole("link", { name: "会社概要" });
    expect(about.getAttribute("href")).toBe("https://umaxica.com/about");
    // A document visit, so no Inertia interception marker.
    expect(Object.hasOwn(about.dataset, "inertia")).toBe(false);
  });

  test("keeps the footer navigation links inside lists so they can be counted", () => {
    render({
      ...minimalChrome,
      footer_navigation: [
        { label: "ホーム", href: "https://umaxica.app/" },
        { label: "設定", href: "https://umaxica.app/settings" },
      ],
    });

    const footer = screen.getByRole("navigation", { name: "Footer" });
    expect(within(footer).getAllByRole("listitem")).toHaveLength(2);
  });
});
