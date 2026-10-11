import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The screen components read `usePage().props.errors` and submit through `router`, neither of which
// exists outside a booted Inertia application. `Link` is stubbed to the anchor it renders so the
// static markup stays assertable.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { patch: vi.fn(), delete: vi.fn() },
  usePage: () => ({
    props: { errors: { confirm_reset: "確認が必要です", option_id: "選択してください" } },
  }),
}));

const { default: PreferenceSelect } = await import("@/features/preferences/PreferenceSelect");
const { default: PreferenceCookie } = await import("@/features/preferences/PreferenceCookie");
const { default: PreferenceCustomization } =
  await import("@/features/preferences/PreferenceCustomization");
const { default: BaseOrgOption } = await import("@/pages/base/org/preference/option");
const { default: BaseComSelectable } = await import("@/pages/base/com/preference/selectable");
const { default: BaseAppCookie } = await import("@/pages/base/app/preference/cookie");
const { default: BaseAppCustomizations } =
  await import("@/pages/base/app/preference/customizations");

const backLink = { label: "もどる", href: "/preference?ri=jp" };

describe("preference select screen", () => {
  const props = {
    screen: "region",
    title: "地域設定",
    description: "地域を選びます。",
    back_link: backLink,
    form: {
      action: "/preference/region?ri=jp",
      method: "patch",
      scope: "preference_region",
      field: "option_id",
      label: "地域",
      value: 2,
      choices: [
        { label: "日本", value: 2, disabled: true },
        { label: "アメリカ合衆国 (USA)", value: 1, disabled: false },
      ],
      submit_label: "更新",
      submitting_label: "送信中",
    },
    region_link: null,
    linked_screens: [{ key: "timezone", label: "タイムゾーン", href: "/preference/timezone/edit" }],
  };

  it("renders every choice and preselects the saved one", () => {
    const html = renderToStaticMarkup(<PreferenceSelect {...props} />);

    expect(html).toContain("地域設定");
    expect(html).toContain('name="preference_region[option_id]"');
    expect(html).toContain("日本");
    expect(html).toContain("アメリカ合衆国 (USA)");
    expect(html).toContain('value="2" selected');
  });

  it("links the region screen to the screens that depend on it", () => {
    const html = renderToStaticMarkup(<PreferenceSelect {...props} />);

    expect(html).toContain('href="/preference/timezone/edit"');
  });

  it("omits the dependent screen list on screens other than region", () => {
    const html = renderToStaticMarkup(
      <PreferenceSelect
        {...props}
        screen="theme"
      />,
    );

    expect(html).not.toContain('href="/preference/timezone/edit"');
  });

  it("omits the description paragraph when no description is given", () => {
    const html = renderToStaticMarkup(
      <PreferenceSelect
        {...props}
        description=""
      />,
    );

    expect(html).not.toContain("地域を選びます。");
  });

  it("surfaces a server-side error for the selected field", () => {
    const html = renderToStaticMarkup(
      <PreferenceSelect
        {...props}
        form={{ ...props.form, field: "option_id" }}
      />,
    );

    // `Select`'s field error is wired through `aria-describedby` rather than `role="alert"`,
    // the same convention every other field-level error uses in this codebase.
    expect(html).toContain('data-invalid="true"');
    expect(html).toContain("選択してください");
  });

  it("links to the region screen when a region link is given", () => {
    const html = renderToStaticMarkup(
      <PreferenceSelect
        {...props}
        region_link={{ label: "地域設定へ", href: "/preference/region/edit?ri=jp" }}
      />,
    );

    expect(html).toContain('href="/preference/region/edit?ri=jp"');
    expect(html).toContain("地域設定へ");
  });
});

describe("preference cookie screen", () => {
  const props = {
    screen: "cookie",
    title: "クッキー設定",
    description: "同意する範囲を選びます。",
    back_link: backLink,
    form: {
      action: "/preference/cookie?ri=jp",
      method: "patch",
      scope: "preference_cookie",
      necessary_label: "必須クッキー",
      categories: [
        { key: "functional", label: "機能", value: true },
        { key: "consented", label: "同意", value: false },
      ],
      submit_label: "更新",
      submitting_label: "送信中",
    },
  };

  it("renders one checkbox per category plus the read-only necessary row", () => {
    const html = renderToStaticMarkup(<PreferenceCookie {...props} />);

    expect(html).toContain('name="preference_cookie[functional]"');
    expect(html).toContain('name="preference_cookie[consented]"');
    expect(html).toContain("必須クッキー");
    // Strictly necessary cookies cannot be declined.
    expect(html).toContain("disabled");
  });
});

describe("preference customization screen", () => {
  const props = {
    screen: "customization",
    title: "設定のリセット",
    description: "すべての設定を初期化します。",
    back_link: backLink,
    form: {
      action: "/preference/customization?ri=jp",
      method: "delete",
      field: "confirm_reset",
      label: "リセットに同意する",
      value: false,
      submit_label: "リセット",
      submitting_label: "送信中",
    },
  };

  it("requires confirmation and surfaces the server error", () => {
    const html = renderToStaticMarkup(<PreferenceCustomization {...props} />);

    expect(html).toContain('name="confirm_reset"');
    expect(html).toContain("required");
    expect(html).toContain("確認が必要です");
  });
});

describe("surface page modules", () => {
  it.each([
    ["base/org option", BaseOrgOption, PreferenceSelect],
    ["base/com selectable", BaseComSelectable, PreferenceSelect],
    ["base/app cookie", BaseAppCookie, PreferenceCookie],
    ["base/app customizations", BaseAppCustomizations, PreferenceCustomization],
  ])("%s resolves to its shared component", (_name, pageModule, component) => {
    expect(pageModule).toBe(component);
  });
});
