import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

// The list of destinations. What matters is that a row the server withheld a URL from is not
// offered as one — the visitor should see the ceremony exists without being able to start it here.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a
      href={href}
      data-inertia="true"
    >
      {children}
    </a>
  ),
}));

const { default: NavList } = await import("@/components/ui/NavList");

describe("NavList", () => {
  it("renders one list item per entry", () => {
    render(
      <NavList
        label="Methods"
        items={[
          { label: "Passkey", href: "/passkeys/new" },
          { label: "Authenticator app", href: "/totps/new" },
        ]}
      />,
    );

    expect(screen.getByRole("list", { name: "Methods" })).toBeTruthy();
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
    expect(screen.getByRole("link", { name: "Passkey" }).getAttribute("href")).toBe(
      "/passkeys/new",
    );
  });

  it("renders a row without a destination as text rather than a link", () => {
    render(<NavList items={[{ label: "Recovery code", href: null }]} />);

    expect(screen.queryByRole("link")).toBeNull();
    expect(screen.getByText("Recovery code")).toBeTruthy();
  });

  it("keeps the description out of the link's accessible name only when absent", () => {
    render(
      <NavList
        items={[{ label: "Authenticator app", href: "/totps/new", description: "Six digits." }]}
      />,
    );

    expect(screen.getByRole("link", { name: /Authenticator app/u }).getAttribute("href")).toBe(
      "/totps/new",
    );
    expect(screen.getByText("Six digits.")).toBeTruthy();
  });

  it("visits client-side only when told the destination is on this surface", () => {
    const { rerender } = render(<NavList items={[{ label: "Cookies", href: "/cookies" }]} />);
    expect(screen.getByRole("link", { name: "Cookies" }).dataset["inertia"]).toBeUndefined();

    rerender(
      <NavList
        items={[{ label: "Cookies", href: "/cookies" }]}
        visit="inertia"
      />,
    );
    expect(screen.getByRole("link", { name: "Cookies" }).dataset["inertia"]).toBe("true");
  });
});
