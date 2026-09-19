import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

const { default: ActivityIndex } = await import("@/features/identity/ActivityIndex");

const columns = {
  occurred_at: "Occurred at",
  activity: "Activity",
  device: "Device",
  source: "Source",
  risk: "Risk",
};

describe("ActivityIndex", () => {
  it("renders one row per activity the server sent", () => {
    const markup = renderToStaticMarkup(
      <ActivityIndex
        title="Activity"
        description="Recent events."
        back_link={{ label: "Back", href: "/identity" }}
        empty_message="No activity."
        columns={columns}
        activities={[
          {
            occurred_at: "1 January 2026",
            activity: "Google sign-in",
            device: "Firefox / Linux",
            source: "Location unavailable",
            risk: "Low",
            risk_rank: 1,
          },
        ]}
      />,
    );

    expect(markup).toContain("Google sign-in");
    expect(markup).toContain("Firefox / Linux");
    expect(markup).toContain("Location unavailable");
    expect(markup).toContain("Low");
    expect(markup).not.toContain("203.0.113.4");
    expect(markup).not.toContain("{}");
    expect(markup).not.toContain("No activity.");
  });

  it("shows the empty message when there are no activities", () => {
    const markup = renderToStaticMarkup(
      <ActivityIndex
        title="Activity"
        description="Recent events."
        back_link={{ label: "Back", href: "/identity" }}
        empty_message="No activity."
        columns={columns}
        activities={[]}
      />,
    );

    expect(markup).toContain("No activity.");
    expect(markup).not.toContain("<table");
  });
});
