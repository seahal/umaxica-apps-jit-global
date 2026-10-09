import { render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

// The page shell. Its contract is the document hierarchy `docs/design.md` states every screen
// follows — up, title, description, body — so these assert the landmarks and the heading level a
// visitor navigates by, not the classes that paint them.
//
// Inertia is mocked because the only thing the adapter contributes here is which element the up
// link becomes; the marker below is what distinguishes the two.
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

const { default: Card } = await import("@/components/ui/Card");
const { default: Page } = await import("@/components/ui/Page");

describe("Page", () => {
  it("renders the title as the page's only first-level heading", () => {
    render(
      <Page
        title="Sessions"
        description="Every session on this account."
      >
        <p>body</p>
      </Page>,
    );

    expect(screen.getAllByRole("heading", { level: 1 })).toHaveLength(1);
    expect(screen.getByRole("heading", { level: 1, name: "Sessions" })).toBeTruthy();
    expect(screen.getByText("Every session on this account.")).toBeTruthy();
    expect(screen.getByText("body")).toBeTruthy();
  });

  it("renders no header at all when the page carries none", () => {
    const { container } = render(
      <Page>
        <p>body</p>
      </Page>,
    );

    expect(container.querySelector("header")).toBeNull();
    expect(screen.getByText("body")).toBeTruthy();
  });

  it("renders the up link ahead of the title, named by its label alone", () => {
    render(
      <Page
        title="Passkeys"
        up={{ label: "Settings", href: "/settings" }}
      >
        <p>body</p>
      </Page>,
    );

    // The arrow is decorative, so it must not reach the accessible name.
    const up = screen.getByRole("link", { name: "Settings" });
    expect(up.getAttribute("href")).toBe("/settings");
  });

  it("follows the up link as a document visit by default", () => {
    render(
      <Page
        title="Passkeys"
        up={{ label: "Settings", href: "/settings" }}
      >
        <p>body</p>
      </Page>,
    );

    expect(screen.getByRole("link", { name: "Settings" }).dataset["inertia"]).toBeUndefined();
  });

  it("follows the up link as an Inertia visit when the parent is on this surface", () => {
    render(
      <Page
        title="Passkeys"
        up={{ label: "Settings", href: "/settings" }}
        upVisit="inertia"
      >
        <p>body</p>
      </Page>,
    );

    expect(screen.getByRole("link", { name: "Settings" }).dataset["inertia"]).toBe("true");
  });

  it("renders page-level actions beside the title", () => {
    render(
      <Page
        title="Passkeys"
        actions={<button type="button">Add</button>}
      >
        <p>body</p>
      </Page>,
    );

    // The `<header>` is the banner landmark here because nothing sectioning wraps it in isolation;
    // in the application it sits inside the layout's `<main>`. Scoping to it is what asserts the
    // action belongs to the page rather than to the body below it.
    const header = screen.getByRole("banner");
    expect(within(header).getByRole("heading", { level: 1, name: "Passkeys" })).toBeTruthy();
    expect(within(header).getByRole("button", { name: "Add" })).toBeTruthy();
  });

  it("renders the up link without a title", () => {
    render(
      <Page up={{ label: "Settings", href: "/settings" }}>
        <p>body</p>
      </Page>,
    );

    expect(screen.getByRole("link", { name: "Settings" })).toBeTruthy();
    expect(screen.queryByRole("heading", { level: 1 })).toBeNull();
  });
});

describe("Card", () => {
  it("renders actions without a heading", () => {
    render(
      <Card actions={<button type="button">Edit</button>}>
        <p>body</p>
      </Card>,
    );

    expect(screen.getByRole("button", { name: "Edit" })).toBeTruthy();
    expect(screen.queryByRole("heading", { level: 2 })).toBeNull();
  });
});

describe("Page actions without a title", () => {
  it("keeps page actions reachable when the page supplies its own heading", () => {
    render(
      <Page actions={<button type="button">Export</button>}>
        <h1>Report</h1>
      </Page>,
    );
    expect(screen.getByRole("button", { name: "Export" })).toBeTruthy();
  });
});
