import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import SurfaceDashboard, { type SurfaceDashboardProps } from "@/features/auth/SurfaceDashboard";
import BaseAppDashboardsShow from "@/pages/base/app/dashboards/show";
import BaseComDashboardsShow from "@/pages/base/com/dashboards/show";
import BaseOrgDashboardsShow from "@/pages/base/org/dashboards/show";

const props: SurfaceDashboardProps = {
  title: "Dashboard",
  sections: [
    {
      heading: "Menu links",
      current_identity: { display_name: "Selected Persona" },
      items: [
        { label: "Preference", href: "/preference?ri=jp" },
        { label: "Switcher", href: "/switcher?ri=jp" },
        { label: "Logout", href: "/sign/out/new?ri=jp" },
      ],
    },
  ],
};

describe("Base Dashboard identity navigation", () => {
  it("renders the selected Persona before Preference, Switcher, and Logout", () => {
    const markup = renderToStaticMarkup(<SurfaceDashboard {...props} />);
    const identityIndex = markup.indexOf("Selected Persona");
    const preferenceIndex = markup.indexOf("Preference");
    const switcherIndex = markup.indexOf("Switcher");
    const logoutIndex = markup.indexOf("Logout");

    expect(identityIndex).toBeGreaterThanOrEqual(0);
    expect(identityIndex).toBeLessThan(preferenceIndex);
    expect(preferenceIndex).toBeLessThan(switcherIndex);
    expect(switcherIndex).toBeLessThan(logoutIndex);
  });

  it.each([
    ["base/app", BaseAppDashboardsShow],
    ["base/com", BaseComDashboardsShow],
    ["base/org", BaseOrgDashboardsShow],
  ])("%s uses the shared Dashboard renderer", (_surface, Page) => {
    expect(Page).toBe(SurfaceDashboard);
  });
});
