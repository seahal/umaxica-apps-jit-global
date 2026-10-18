import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import WarpSettings, { type WarpSettingsProps } from "@/features/dashboards/WarpSettings";
import WarpAppSettingsShow from "@/pages/warp/app/settings/show";
import WarpComSettingsShow from "@/pages/warp/com/settings/show";
import WarpOrgSettingsShow from "@/pages/warp/org/settings/show";

const props: WarpSettingsProps = {
  title: "Settings",
  heading: "Settings",
  description: "Warp app control-plane settings.",
  links: [
    { label: "Dashboard", href: "/dashboards?ri=jp" },
    { label: "Sign out", href: "/sign/out/new?ri=jp" },
  ],
};

describe("WarpSettings", () => {
  it("renders the heading and the description the server built", () => {
    const markup = renderToStaticMarkup(<WarpSettings {...props} />);

    expect(markup).toContain("<h1");
    expect(markup).toContain("Settings");
    expect(markup).toContain("Warp app control-plane settings.");
  });

  it("renders every link the server generated", () => {
    const markup = renderToStaticMarkup(<WarpSettings {...props} />);

    expect(markup).toContain('href="/dashboards?ri=jp"');
    expect(markup).toContain("Dashboard");
    expect(markup).toContain('href="/sign/out/new?ri=jp"');
    expect(markup).toContain("Sign out");
  });

  it("renders nothing extra when the server sends no links", () => {
    const markup = renderToStaticMarkup(
      <WarpSettings
        {...props}
        links={[]}
      />,
    );

    expect(markup).not.toContain("<a href");
  });
});

describe("side settings pages", () => {
  it.each([
    ["warp/app", WarpAppSettingsShow],
    ["warp/com", WarpComSettingsShow],
    ["warp/org", WarpOrgSettingsShow],
  ])("%s renders the shared settings page", (_surface, Page) => {
    expect(Page).toBe(WarpSettings);
  });
});
