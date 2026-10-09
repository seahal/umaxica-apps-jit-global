import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

// The two link primitives. Both exist so one appearance is defined once; what a test can assert
// about them is the choice that is not cosmetic — whether following the link is a client-side
// visit or a document load. Getting that wrong on a cross-surface destination sends an XHR to
// another origin, which CORS rejects, so it is worth pinning.
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

const { default: ButtonLink } = await import("@/components/ui/ButtonLink");
const { default: TextLink } = await import("@/components/ui/TextLink");
const { default: Table } = await import("@/components/ui/Table");

describe("ButtonLink", () => {
  it("is a document visit by default", () => {
    render(<ButtonLink href="/settings">Add</ButtonLink>);

    const link = screen.getByRole("link", { name: "Add" });
    expect(link.getAttribute("href")).toBe("/settings");
    expect(link.dataset["inertia"]).toBeUndefined();
  });

  it("is a client-side visit when the destination is on this surface", () => {
    render(
      <ButtonLink
        href="/settings"
        inertia
      >
        Add
      </ButtonLink>,
    );

    expect(screen.getByRole("link", { name: "Add" }).dataset["inertia"]).toBe("true");
  });

  it("wears the same appearance as the button of the same variant", () => {
    render(
      <ButtonLink
        href="/settings"
        variant="danger"
      >
        Remove
      </ButtonLink>,
    );

    // The token, not the hex: what matters is that it resolves the danger role rather than
    // restating a colour of its own.
    expect(screen.getByRole("link", { name: "Remove" }).className).toContain("bg-danger");
  });
});

describe("TextLink", () => {
  it("is a document visit by default and a client-side visit when asked", () => {
    const { rerender } = render(<TextLink href="/help">Help</TextLink>);
    expect(screen.getByRole("link", { name: "Help" }).dataset["inertia"]).toBeUndefined();

    rerender(
      <TextLink
        href="/help"
        inertia
      >
        Help
      </TextLink>,
    );
    expect(screen.getByRole("link", { name: "Help" }).dataset["inertia"]).toBe("true");
  });
});

describe("Table", () => {
  it("keeps the rows a real table so headers stay associated with their cells", () => {
    render(
      <Table label="Sessions">
        <thead>
          <tr>
            <th scope="col">Session</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>ses_01</td>
          </tr>
        </tbody>
      </Table>,
    );

    expect(screen.getByRole("table", { name: "Sessions" })).toBeTruthy();
    expect(screen.getByRole("columnheader", { name: "Session" })).toBeTruthy();
    expect(screen.getByRole("cell", { name: "ses_01" })).toBeTruthy();
  });

  it("scrolls the table rather than the page when it is wider than the column", () => {
    const { container } = render(
      <Table>
        <tbody>
          <tr>
            <td>ses_01</td>
          </tr>
        </tbody>
      </Table>,
    );

    expect(container.querySelector(".overflow-x-auto")).not.toBeNull();
  });
});
