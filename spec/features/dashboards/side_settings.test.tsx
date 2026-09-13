import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import SideSettings, { type SideSettingsProps } from "@/features/dashboards/SideSettings";
import SideAppSettingsShow from "@/pages/side/app/settings/show";
import SideComSettingsShow from "@/pages/side/com/settings/show";
import SideOrgSettingsShow from "@/pages/side/org/settings/show";

const props: SideSettingsProps = {
  title: "Settings",
  heading: "Settings",
  description: "Side app control-plane settings.",
  links: [
    { label: "Dashboard", href: "/dashboards?ri=jp" },
    { label: "Sign out", href: "/sign/out/new?ri=jp" },
  ],
};

describe("SideSettings", () => {
  it("renders the heading and the description the server built", () => {
    const markup = renderToStaticMarkup(<SideSettings {...props} />);

    expect(markup).toContain("<h1");
    expect(markup).toContain("Settings");
    expect(markup).toContain("Side app control-plane settings.");
  });

  it("renders every link the server generated", () => {
    const markup = renderToStaticMarkup(<SideSettings {...props} />);

    expect(markup).toContain('href="/dashboards?ri=jp"');
    expect(markup).toContain("Dashboard");
    expect(markup).toContain('href="/sign/out/new?ri=jp"');
    expect(markup).toContain("Sign out");
  });

  it("renders nothing extra when the server sends no links", () => {
    const markup = renderToStaticMarkup(
      <SideSettings
        {...props}
        links={[]}
      />,
    );

    expect(markup).not.toContain("<a href");
  });
});

describe("side settings pages", () => {
  it.each([
    ["side/app", SideAppSettingsShow],
    ["side/com", SideComSettingsShow],
    ["side/org", SideOrgSettingsShow],
  ])("%s renders the shared settings page", (_surface, Page) => {
    expect(Page).toBe(SideSettings);
  });
});
