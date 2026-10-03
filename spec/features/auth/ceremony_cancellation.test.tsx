import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";

import CeremonyCancellation from "@/features/auth/CeremonyCancellation";

// Cancelling a ceremony is a document form post. The authenticity token is read from the document
// when the form is submitted, never when it is rendered, so a token rotated after render is still
// the one that travels.
afterEach(() => {
  document.head.querySelectorAll('meta[name="csrf-token"]').forEach((meta) => meta.remove());
});

describe("CeremonyCancellation", () => {
  it("submits the token the document carries at submit time, not the one present at render", () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "token-at-render";
    document.head.append(meta);

    const { container } = render(
      <CeremonyCancellation
        label="Cancel"
        action="/settings/totps/enrollment?ri=jp"
        method="delete"
      />,
    );
    const token = container.querySelector<HTMLInputElement>('input[name="authenticity_token"]');

    expect(token?.value).toBe("");

    meta.content = "token-at-submit";
    fireEvent.submit(screen.getByRole("button", { name: "Cancel" }));

    expect(token?.value).toBe("token-at-submit");
  });

  it("submits an empty token when the document has no csrf-token meta tag", () => {
    const { container } = render(
      <CeremonyCancellation
        label="Cancel"
        action="/sign/in/session"
        method="post"
      />,
    );

    fireEvent.submit(screen.getByRole("button", { name: "Cancel" }));

    expect(
      container.querySelector<HTMLInputElement>('input[name="authenticity_token"]')?.value,
    ).toBe("");
  });

  it("always posts the document form and names DELETE through the _method override", () => {
    const { container } = render(
      <CeremonyCancellation
        label="Cancel"
        action="/settings/totps/enrollment?ri=jp"
        method="delete"
      />,
    );
    const form = container.querySelector("form");

    expect(form?.getAttribute("method")).toBe("post");
    expect(form?.getAttribute("action")).toBe("/settings/totps/enrollment?ri=jp");
    expect(form?.dataset["turbo"]).toBe("false");
    expect(container.querySelector<HTMLInputElement>('input[name="_method"]')?.value).toBe(
      "delete",
    );
  });

  it("sends no _method override when the server route is a POST", () => {
    const { container } = render(
      <CeremonyCancellation
        label="Cancel"
        action="/sign/in/session"
        method="post"
      />,
    );

    expect(container.querySelector('input[name="_method"]')).toBeNull();
  });
});
