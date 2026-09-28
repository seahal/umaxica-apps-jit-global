import { getByRole } from "@testing-library/dom";
import { act, useState } from "react";
import { createRoot, type Root } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";

import { present } from "../../support/present";

// The org administration screens (Support, Enforcement, IAM). Inertia is mocked because these specs
// exercise the components, not the transport.
const post = vi.fn();
const transform = vi.fn();

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
      errors: {},
      processing: false,
      transform,
      post,
    };
  },
}));

const { default: AdminRecordList } = await import("@/features/org_admin/AdminRecordList");
const { default: AdminRecord } = await import("@/features/org_admin/AdminRecord");
const { default: AdminConfirmation, nestFieldNames } =
  await import("@/features/org_admin/AdminConfirmation");

const context = {
  operator_label: "Acting operator",
  operator_public_id: "BCDE2345FGHJ67KM",
  realm_label: "Target realm",
  realm: "app",
};

let container: HTMLDivElement | null = null;
let root: Root | null = null;

afterEach(() => {
  if (root) {
    act(() => {
      root?.unmount();
    });
  }
  container?.remove();
  container = null;
  root = null;
  post.mockClear();
  transform.mockClear();
});

describe("AdminRecordList", () => {
  it("states the acting operator and the realm in text, not only by colour", () => {
    const html = renderToStaticMarkup(
      <AdminRecordList
        title="App clients"
        context={context}
        columns={["Public ID"]}
        rows={[]}
        empty_message="No clients match."
        search={null}
        pagination={{ previous: null, next: null }}
        actions={[]}
      />,
    );

    expect(html).toContain("BCDE2345FGHJ67KM");
    expect(html).toContain("Target realm");
    expect(html).toContain("app");
    expect(html).toContain("No clients match.");
  });

  it("links each row to the record the server resolved", () => {
    const html = renderToStaticMarkup(
      <AdminRecordList
        title="App clients"
        context={context}
        columns={["Public ID", "Access state"]}
        rows={[{ key: "one", cells: ["one", "enabled"], href: "/support/clients/one" }]}
        empty_message="No clients match."
        search={null}
        pagination={{
          previous: null,
          next: { label: "Next page", href: "/support/clients?page=2" },
        }}
        actions={[]}
      />,
    );

    expect(html).toContain('href="/support/clients/one"');
    expect(html).toContain('href="/support/clients?page=2"');
    expect(html).not.toContain("No clients match.");
  });
});

describe("AdminRecord", () => {
  it("shows a warning notice for an unconfirmed result instead of presenting it as complete", () => {
    const html = renderToStaticMarkup(
      <AdminRecord
        title="Session revocation result"
        context={context}
        notices={[
          { tone: "warning", message: "The audit record of this operation is not complete." },
        ]}
        fields={[{ term: "Result", description: "Not confirmed" }]}
        actions={[]}
        sections={[]}
      />,
    );

    expect(html).toContain('role="alert"');
    expect(html).toContain("Not confirmed");
  });
});

describe("nestFieldNames", () => {
  it("nests one bracketed level and leaves plain names flat", () => {
    expect(
      nestFieldNames({
        "enforcement_case[kind]": "cooldown",
        "enforcement_case[reason_code]": "abuse",
        "principal_effect[access_blocking]": "true",
        operation_id: "id",
      }),
    ).toEqual({
      enforcement_case: { kind: "cooldown", reason_code: "abuse" },
      principal_effect: { access_blocking: "true" },
      operation_id: "id",
    });
  });

  it("keeps a name that is not exactly one bracketed level as a flat key", () => {
    expect(nestFieldNames({ "a[b][c]": "x", "": "empty", "A[b]": "upper" })).toEqual({
      "a[b][c]": "x",
      "": "empty",
      "A[b]": "upper",
    });
  });
});

describe("AdminConfirmation", () => {
  it("does not submit until the operator acknowledges the target and reason", () => {
    container = document.createElement("div");
    document.body.append(container);
    root = createRoot(container);
    act(() => {
      root?.render(
        <AdminConfirmation
          title="Revoke all sessions"
          context={context}
          target={[{ term: "Public ID", description: "one" }]}
          effect="Every session this account has right now is ended."
          action="/support/clients/one/revocations"
          fields={[
            { kind: "hidden", name: "operation_id", value: "4f1c6a52-0f0e-4b1e-9f3a-2d3c4b5a6e7f" },
            {
              kind: "text",
              name: "ticket_id",
              label: "Ticket ID",
              value: "",
              maxlength: 64,
              required: false,
            },
          ]}
          acknowledgement="I have checked the target account and the reason."
          submit_label="Revoke sessions"
        />,
      );
    });
    const mounted = present(container, "the mounted container");
    const submit = getByRole(mounted, "button", { name: "Revoke sessions" });

    expect(submit.dataset["disabled"]).toBe("true");

    const form = present(mounted.querySelector("form"), "the confirmation form");
    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(post).not.toHaveBeenCalled();

    act(() => {
      getByRole(mounted, "checkbox").click();
    });
    act(() => {
      form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });

    expect(transform).toHaveBeenCalledTimes(1);
    expect(post).toHaveBeenCalledWith("/support/clients/one/revocations");
  });
});
