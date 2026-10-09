import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import RootLanding, { type RootLandingProps } from "@/features/landing/RootLanding";
import CoreAppRootsIndex from "@/pages/core/app/roots/index";
import CoreComRootsIndex from "@/pages/core/com/roots/index";
import CoreOrgRootsIndex from "@/pages/core/org/roots/index";
import PalmAppRootsIndex from "@/pages/palm/app/roots/index";
import WarpAppRootsIndex from "@/pages/warp/app/roots/index";
import WarpComRootsIndex from "@/pages/warp/com/roots/index";
import WarpOrgRootsIndex from "@/pages/warp/org/roots/index";

const props: RootLandingProps = {
  title: null,
  heading: "Warp App",
  description: "Thin landing endpoint.",
  sign_up: null,
  links: [
    { label: "Settings", href: "/settings?ri=jp" },
    { label: "Sign up", href: "/oidc/authorization?ri=jp" },
  ],
};

describe("RootLanding extra destinations", () => {
  it("renders every destination the server sent, in order", () => {
    const markup = renderToStaticMarkup(<RootLanding {...props} />);

    expect(markup).toMatch(/<a href="\/settings\?ri=jp"[^>]*>Settings<\/a>/u);
    expect(markup).toMatch(/<a href="\/oidc\/authorization\?ri=jp"[^>]*>Sign up<\/a>/u);
    expect(markup.indexOf('href="/settings?ri=jp"')).toBeLessThan(
      markup.indexOf('href="/oidc/authorization?ri=jp"'),
    );
  });

  it("renders the heading a surface without a page title of its own still shows", () => {
    const markup = renderToStaticMarkup(<RootLanding {...props} />);

    expect(markup).toContain("Warp App");
    expect(markup).toContain("Thin landing endpoint.");
  });

  it("renders no destinations when the surface offers none", () => {
    const markup = renderToStaticMarkup(
      <RootLanding
        {...props}
        links={null}
      />,
    );

    expect(markup).not.toContain("<a href");
  });
});

describe("Core, Warp, and Palm root pages", () => {
  // Each surface resolves pages only from its own directory, so every surface needs its own module
  // for the shared landing.
  it.each([
    ["core/app", CoreAppRootsIndex],
    ["core/com", CoreComRootsIndex],
    ["core/org", CoreOrgRootsIndex],
    ["warp/app", WarpAppRootsIndex],
    ["warp/com", WarpComRootsIndex],
    ["warp/org", WarpOrgRootsIndex],
    ["palm/app", PalmAppRootsIndex],
  ])("%s renders the shared landing", (_surface, Page) => {
    expect(Page).toBe(RootLanding);
  });
});
