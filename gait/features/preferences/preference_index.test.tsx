import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import PreferenceIndex, { type PreferenceIndexProps } from "@/features/preferences/PreferenceIndex";
import BaseAppPreferencesShow from "@/pages/base/app/preferences/show";
import BaseComPreferencesShow from "@/pages/base/com/preferences/show";
import BaseOrgPreferencesShow from "@/pages/base/org/preferences/show";

const props: PreferenceIndexProps = {
  title: "設定",
  description: "この端末の表示設定を変更します。",
  up_link: { label: "戻る", href: "/?ri=jp" },
  screens: [
    { key: "region", label: "地域の設定", href: "/preference/region/edit?ri=jp" },
    { key: "theme", label: "テーマの設定", href: "/preference/theme/edit?ri=jp" },
  ],
};

describe("preference index page", () => {
  it("renders the title, description and one link per screen", () => {
    const html = renderToStaticMarkup(<PreferenceIndex {...props} />);

    expect(html).toContain("設定");
    expect(html).toContain("この端末の表示設定を変更します。");
    expect(html).toContain('href="/preference/region/edit?ri=jp"');
    expect(html).toContain('href="/preference/theme/edit?ri=jp"');
    expect(html).toContain('href="/?ri=jp"');
  });

  // The up link leaves the preference tree for a server rendered page, so it must stay an anchor
  // the browser follows rather than an Inertia visit that would reject a non-Inertia response.
  it("renders the up link as an anchor outside the screen list", () => {
    const html = renderToStaticMarkup(<PreferenceIndex {...props} />);
    const upLinkIndex = html.indexOf('href="/?ri=jp"');
    const listIndex = html.indexOf("<ul");

    expect(upLinkIndex).toBeGreaterThan(-1);
    expect(upLinkIndex).toBeLessThan(listIndex);
  });

  it.each([
    ["base/app", BaseAppPreferencesShow],
    ["base/com", BaseComPreferencesShow],
    ["base/org", BaseOrgPreferencesShow],
  ])("%s resolves its own page module to the shared component", (_surface, component) => {
    expect(component).toBe(PreferenceIndex);
  });
});
