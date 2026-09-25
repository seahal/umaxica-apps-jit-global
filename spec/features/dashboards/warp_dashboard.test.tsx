import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import WarpDashboard, { type WarpDashboardProps } from "@/features/dashboards/WarpDashboard";
import WarpAppDashboardsShow from "@/pages/warp/app/dashboards/show";
import WarpComDashboardsShow from "@/pages/warp/com/dashboards/show";
import WarpOrgDashboardsShow from "@/pages/warp/org/dashboards/show";

const props: WarpDashboardProps = {
  title: "Dashboard",
  heading: "Dashboard",
  description: "Warp app signed-in landing.",
  sections: [
    {
      title: "Primary links",
      links: [
        { label: "Root", href: "/?ri=jp" },
        { label: "Sign out", href: "/sign/out/new?ri=jp" },
      ],
    },
    {
      title: "Protocol links",
      links: [{ label: "Authorize", href: "/oidc/authorization?ri=jp" }],
    },
  ],
};

describe("WarpDashboard", () => {
  it("renders the heading and the description the server built", () => {
    const markup = renderToStaticMarkup(<WarpDashboard {...props} />);

    expect(markup).toContain("<h1");
    expect(markup).toContain("Dashboard");
    expect(markup).toContain("Warp app signed-in landing.");
  });

  it("renders every section with the links the server generated", () => {
    const markup = renderToStaticMarkup(<WarpDashboard {...props} />);

    expect(markup).toContain("Primary links");
    expect(markup).toContain("Protocol links");
    expect(markup).toMatch(/<a href="\/\?ri=jp"[^>]*>Root<\/a>/u);
    expect(markup).toMatch(/<a href="\/sign\/out\/new\?ri=jp"[^>]*>Sign out<\/a>/u);
    expect(markup).toMatch(/<a href="\/oidc\/authorization\?ri=jp"[^>]*>Authorize<\/a>/u);
  });

  it("renders nothing extra when the server sends no sections", () => {
    const markup = renderToStaticMarkup(
      <WarpDashboard
        {...props}
        sections={[]}
      />,
    );

    expect(markup).not.toContain("<a href");
  });
});

describe("Warp dashboard pages", () => {
  it.each([
    ["warp/app", WarpAppDashboardsShow],
    ["warp/com", WarpComDashboardsShow],
    ["warp/org", WarpOrgDashboardsShow],
  ])("%s renders the shared dashboard", (_surface, Page) => {
    expect(Page).toBe(WarpDashboard);
  });
});
