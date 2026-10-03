import { fireEvent, render, screen, within } from "@testing-library/react";
import { useState } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

// The org administration screens render whatever the server resolved: records, the operations an
// operator may start, and the confirmation form for a mutation. Inertia's form transport is
// replaced because these specs exercise what the screens show and what they hand to the transport.
const post = vi.fn();
const transform = vi.fn<(nest: (data: Record<string, string>) => unknown) => void>();
let formErrors: Record<string, string> = {};

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  usePage: () => ({ props: {} }),
  useForm: (initial: Record<string, string>) => {
    const [data, setDataState] = useState(initial);

    return {
      data,
      setData: (key: string, value: string) =>
        setDataState((current) => ({ ...current, [key]: value })),
      errors: formErrors,
      processing: false,
      transform,
      post,
    };
  },
}));

const { default: AdminRecordList } = await import("@/features/org_admin/AdminRecordList");
const { default: AdminRecord } = await import("@/features/org_admin/AdminRecord");
const { default: AdminConfirmation } = await import("@/features/org_admin/AdminConfirmation");

const context = {
  operator_label: "Acting operator",
  operator_public_id: "BCDE2345FGHJ67KM",
  realm_label: "Target realm",
  realm: "app",
};

afterEach(() => {
  formErrors = {};
  post.mockClear();
  transform.mockClear();
});

describe("AdminRecord", () => {
  it("offers each operation the server authorized as a link to its confirmation screen", () => {
    render(
      <AdminRecord
        title="Client"
        description="One app client"
        context={context}
        fields={[{ term: "Public ID", description: "one" }]}
        actions={[
          { label: "Revoke all sessions", href: "/support/clients/one/revocations/new" },
          { label: "Open enforcement case", href: "/support/enforcement_cases/new?client=one" },
        ]}
        sections={[]}
      />,
    );

    expect(screen.getByRole("link", { name: "Revoke all sessions" }).getAttribute("href")).toBe(
      "/support/clients/one/revocations/new",
    );
    expect(screen.getByRole("link", { name: "Open enforcement case" }).getAttribute("href")).toBe(
      "/support/enforcement_cases/new?client=one",
    );
    expect(screen.getByText("One app client")).toBeTruthy();
  });

  it("renders a section's fields and links, and no empty message while it has content", () => {
    render(
      <AdminRecord
        title="Client"
        context={context}
        fields={[]}
        actions={[]}
        sections={[
          {
            heading: "Enforcement",
            fields: [{ term: "Access state", description: "blocked" }],
            links: [{ label: "Case 42", href: "/support/enforcement_cases/42" }],
            empty_message: "No enforcement cases.",
          },
        ]}
      />,
    );

    expect(screen.getByText("Enforcement")).toBeTruthy();
    expect(screen.getByText("blocked")).toBeTruthy();
    expect(screen.getByRole("link", { name: "Case 42" }).getAttribute("href")).toBe(
      "/support/enforcement_cases/42",
    );
    expect(screen.queryByText("No enforcement cases.")).toBeNull();
  });

  it("shows the empty message only for a section with neither fields nor links", () => {
    render(
      <AdminRecord
        title="Client"
        context={context}
        fields={[]}
        actions={[]}
        sections={[
          { heading: "Sessions", fields: [], links: [], empty_message: "No active sessions." },
          { heading: "Grants" },
        ]}
      />,
    );

    expect(screen.getByText("No active sessions.")).toBeTruthy();
    expect(screen.getByText("Grants")).toBeTruthy();
    expect(screen.queryAllByRole("link")).toHaveLength(0);
  });

  it("omits the realm row for a screen that acts on no realm", () => {
    render(
      <AdminRecord
        title="Grant"
        context={{ ...context, realm_label: null, realm: null }}
        fields={[]}
        actions={[]}
        sections={[]}
      />,
    );

    expect(screen.getByText("BCDE2345FGHJ67KM")).toBeTruthy();
    expect(screen.queryByText("Target realm")).toBeNull();
  });

  it("announces an info notice as status and a danger notice as an alert", () => {
    render(
      <AdminRecord
        title="Result"
        context={context}
        notices={[
          { tone: "info", message: "Sessions were revoked." },
          { tone: "danger", message: "The operation failed." },
        ]}
        fields={[]}
        actions={[]}
        sections={[]}
      />,
    );

    expect(screen.getByRole("status").textContent).toBe("Sessions were revoked.");
    expect(screen.getByRole("alert").textContent).toBe("The operation failed.");
  });
});

describe("AdminRecordList", () => {
  const listProps = {
    title: "App clients",
    context,
    columns: ["Public ID", "Access state"],
    empty_message: "No clients match.",
    pagination: { previous: null, next: null },
    actions: [],
  };

  it("submits the exact-identifier search as a GET to the server-resolved action", () => {
    const { container } = render(
      <AdminRecordList
        {...listProps}
        rows={[]}
        search={{
          action: "/support/clients",
          label: "Public ID",
          name: "public_id",
          value: "BCDE2345",
          submit_label: "Search",
          maxlength: 16,
        }}
      />,
    );
    const form = container.querySelector("form");
    const input = screen.getByRole<HTMLInputElement>("searchbox", { name: "Public ID" });

    expect(form?.getAttribute("method")).toBe("get");
    expect(form?.getAttribute("action")).toBe("/support/clients");
    expect(input.getAttribute("name")).toBe("public_id");
    expect(input.getAttribute("maxlength")).toBe("16");
    expect(input.value).toBe("BCDE2345");
    expect(screen.getByRole("button", { name: "Search" })).toBeTruthy();
  });

  it("renders a row without a resolved record as text, and links only the first cell", () => {
    render(
      <AdminRecordList
        {...listProps}
        rows={[
          { key: "one", cells: ["one", "enabled"], href: "/support/clients/one" },
          { key: "two", cells: ["two", "blocked"], href: null },
        ]}
        search={null}
      />,
    );
    const table = screen.getByRole("table", { name: "App clients" });

    expect(within(table).getAllByRole("link")).toHaveLength(1);
    expect(within(table).getByRole("link", { name: "one" }).getAttribute("href")).toBe(
      "/support/clients/one",
    );
    expect(within(table).getByText("two").closest("a")).toBeNull();
    expect(within(table).getByText("enabled").closest("a")).toBeNull();
  });

  it("links the previous page and the list-level operations the server offered", () => {
    render(
      <AdminRecordList
        {...listProps}
        rows={[]}
        search={null}
        pagination={{
          previous: { label: "Previous page", href: "/support/clients?page=1" },
          next: null,
        }}
        actions={[{ label: "New grant", href: "/iam/grants/new" }]}
      />,
    );

    expect(screen.getByRole("link", { name: "Previous page" }).getAttribute("href")).toBe(
      "/support/clients?page=1",
    );
    expect(screen.getByRole("link", { name: "New grant" }).getAttribute("href")).toBe(
      "/iam/grants/new",
    );
  });
});

describe("AdminConfirmation", () => {
  const confirmationProps = {
    title: "Open enforcement case",
    context,
    target: [{ term: "Public ID", description: "one" }],
    effect: "The account is blocked until the case is released.",
    action: "/support/enforcement_cases",
    acknowledgement: "I have checked the target account and the reason.",
    submit_label: "Open case",
  };

  it("hands the transport the typed text value nested under its bracketed root", () => {
    render(
      <AdminConfirmation
        {...confirmationProps}
        fields={[
          { kind: "hidden", name: "operation_id", value: "op-1" },
          {
            kind: "text",
            name: "enforcement_case[ticket_id]",
            label: "Ticket ID",
            value: "",
            maxlength: 64,
            required: true,
          },
        ]}
      />,
    );

    fireEvent.change(screen.getByRole("textbox", { name: /Ticket ID/u }), {
      target: { value: "T-100" },
    });
    fireEvent.click(screen.getByRole("checkbox"));
    fireEvent.submit(screen.getByRole("button", { name: "Open case" }));

    expect(post).toHaveBeenCalledWith("/support/enforcement_cases");
    const nest = transform.mock.calls[0]?.[0];
    expect(nest?.({ operation_id: "op-1", "enforcement_case[ticket_id]": "T-100" })).toEqual({
      operation_id: "op-1",
      enforcement_case: { ticket_id: "T-100" },
    });
    expect(screen.getByRole<HTMLInputElement>("textbox", { name: /Ticket ID/u }).value).toBe(
      "T-100",
    );
  });

  it("limits a text field to the server's maximum length", () => {
    render(
      <AdminConfirmation
        {...confirmationProps}
        fields={[
          {
            kind: "text",
            name: "ticket_id",
            label: "Ticket ID",
            value: "T-1",
            maxlength: 64,
            required: false,
          },
        ]}
      />,
    );
    const input = screen.getByRole<HTMLInputElement>("textbox", { name: /Ticket ID/u });

    expect(input.getAttribute("maxlength")).toBe("64");
    expect(input.value).toBe("T-1");
  });

  it("shows the server's current choice for a select field", () => {
    render(
      <AdminConfirmation
        {...confirmationProps}
        fields={[
          {
            kind: "select",
            name: "enforcement_case[kind]",
            label: "Kind",
            value: "cooldown",
            options: [
              { value: "cooldown", label: "Cooldown" },
              { value: "suspension", label: "Suspension" },
            ],
          },
        ]}
      />,
    );

    expect(screen.getByRole("button", { name: /Kind/u }).textContent).toContain("Cooldown");
  });

  it("lists the server's validation errors above the form", () => {
    formErrors = { ticket_id: "Ticket ID is too long." };

    render(
      <AdminConfirmation
        {...confirmationProps}
        description="Confirm before submitting."
        fields={[]}
      />,
    );

    expect(screen.getByText("Ticket ID is too long.")).toBeTruthy();
    expect(screen.getByText("Confirm before submitting.")).toBeTruthy();
  });

  it("re-disables submission when the acknowledgement is withdrawn", () => {
    render(
      <AdminConfirmation
        {...confirmationProps}
        fields={[]}
      />,
    );
    const checkbox = screen.getByRole("checkbox");

    fireEvent.click(checkbox);
    fireEvent.click(checkbox);
    fireEvent.submit(screen.getByRole("button", { name: "Open case" }));

    expect(post).not.toHaveBeenCalled();
    expect(transform).not.toHaveBeenCalled();
  });
});
