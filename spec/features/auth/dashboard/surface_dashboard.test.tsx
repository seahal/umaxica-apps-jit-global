import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

import SurfaceDashboard, { type SurfaceDashboardProps } from "@/features/auth/SurfaceDashboard";
import RootLanding from "@/features/landing/RootLanding";
import AuthAppDashboardShow from "@/pages/auth/app/dashboards/show";
import AuthAppRootsIndex from "@/pages/auth/app/roots/index";

const props: SurfaceDashboardProps = {
  title: "Dashboard",
  description: "Sign app signed-in landing.",
  sections: [
    {
      heading: "Primary links",
      items: [{ label: "Root", href: "/?ri=jp" }],
    },
    {
      heading: "Ceremony links",
      items: [
        { label: "Sign-in guard", href: "/sign/in/guard?ri=jp" },
        { label: "Selector: handled by the sign-in guard sequence", href: null },
      ],
    },
  ],
};

describe("SurfaceDashboard", () => {
  it("links the destinations the server resolved", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);

    expect(markup).toMatch(/<h1[^>]*>Dashboard<\/h1>/u);
    expect(markup).toContain("Sign app signed-in landing.");
    expect(markup).toMatch(/<a href="\/\?ri=jp"[^>]*>Root<\/a>/u);
    expect(markup).toMatch(/<a href="\/sign\/in\/guard\?ri=jp"[^>]*>Sign-in guard<\/a>/u);
  });

  it("nests publishing groups under a section heading", () => {
    const markup = renderToStaticMarkup(
      <SurfaceDashboard
        title="Dashboard"
        description="Signed in"
        sections={[
          {
            heading: "Publishing",
            groups: [
              {
                heading: "info",
                items: [
                  { label: "app", href: "/publishing/info/app/entries" },
                  { label: "com", href: "/publishing/info/com/entries" },
                ],
              },
              {
                heading: "docs",
                items: [{ label: "org", href: "/publishing/docs/org/entries" }],
              },
            ],
          },
        ]}
      />,
    );

    expect(markup).toMatch(/<h2[^>]*>Publishing<\/h2>/u);
    expect(markup).toMatch(/<h3[^>]*>info<\/h3>/u);
    expect(markup).toMatch(/<h3[^>]*>docs<\/h3>/u);
    expect(markup).toMatch(/<a href="\/publishing\/info\/app\/entries"[^>]*>app<\/a>/u);
    expect(markup).toMatch(/<a href="\/publishing\/docs\/org\/entries"[^>]*>org<\/a>/u);
  });

  it("renders an entry without a destination as plain text", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);

    expect(markup).toContain("Selector: handled by the sign-in guard sequence");
    expect(markup).not.toMatch(/<a[^>]*>Selector: handled by the sign-in guard sequence<\/a>/u);
  });

  it("renders the dashboard up link above the title when the server sent one", () => {
    const markup = renderToStaticMarkup(
      <SurfaceDashboard
        {...props}
        up_link={{ label: "上へ", href: "/dashboard?ri=jp" }}
      />,
    );
    const upIndex = markup.indexOf('href="/dashboard?ri=jp"');
    const titleIndex = markup.search(/<h1[^>]*>Dashboard<\/h1>/u);

    expect(markup).toContain("上へ");
    expect(upIndex).toBeGreaterThan(-1);
    expect(upIndex).toBeLessThan(titleIndex);
  });

  it("omits the up link when the server did not send one", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);

    expect(markup).not.toContain('href="/dashboard?ri=jp"');
  });
});

describe("auth/app pages", () => {
  it("dashboards/show re-exports the shared dashboard", () => {
    expect(AuthAppDashboardShow).toBe(SurfaceDashboard);
  });

  it("roots/index re-exports the shared landing", () => {
    expect(AuthAppRootsIndex).toBe(RootLanding);
  });
});
