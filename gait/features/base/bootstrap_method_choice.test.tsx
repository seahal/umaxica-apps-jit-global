import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";

import BootstrapMethodChoice from "@/features/base/BootstrapMethodChoice";

// Choosing a first authenticator starts a transaction on the server, so every method is a submit
// button of one document form posting to Base, and the server supplies the list of methods.
afterEach(() => {
  document.head.querySelectorAll('meta[name="csrf-token"]').forEach((meta) => meta.remove());
});

const props = {
  title: "Set up verification",
  description: "Choose a method.",
  methods: [
    { key: "passkey", label: "Passkey" },
    { key: "totp", label: "Authenticator app" },
    { key: "email_otp", label: "Email" },
  ],
  form: { action: "/verification/setup?ri=jp", scope: "settings_telephone", pt: "signed-target" },
  cancel: { href: "/identity?ri=jp", label: "Cancel" },
};

describe("BootstrapMethodChoice", () => {
  it("offers exactly the methods the server sent, each as a submit button carrying its key", () => {
    render(<BootstrapMethodChoice {...props} />);

    const buttons = screen.getAllByRole("button");

    expect(buttons.map((button) => button.textContent)).toEqual([
      "Passkey",
      "Authenticator app",
      "Email",
    ]);
    expect(buttons.map((button) => button.getAttribute("name"))).toEqual([
      "registration_method",
      "registration_method",
      "registration_method",
    ]);
    expect(buttons.map((button) => button.getAttribute("value"))).toEqual([
      "passkey",
      "totp",
      "email_otp",
    ]);
    expect(buttons.every((button) => button.getAttribute("type") === "submit")).toBe(true);
  });

  it("renders no method button when the server sent none", () => {
    render(
      <BootstrapMethodChoice
        {...props}
        methods={[]}
      />,
    );

    expect(screen.queryAllByRole("button")).toEqual([]);
    expect(screen.getByRole("link", { name: "Cancel" }).getAttribute("href")).toBe(
      "/identity?ri=jp",
    );
  });

  it("posts the scope and signed target to the action the server named", () => {
    const { container } = render(<BootstrapMethodChoice {...props} />);
    const form = container.querySelector("form");

    expect(form?.getAttribute("action")).toBe("/verification/setup?ri=jp");
    expect(form?.getAttribute("method")).toBe("post");
    expect(container.querySelector<HTMLInputElement>('input[name="scope"]')?.value).toBe(
      "settings_telephone",
    );
    expect(container.querySelector<HTMLInputElement>('input[name="pt"]')?.value).toBe(
      "signed-target",
    );
  });

  it("submits the token the document carries at submit time, not the one present at render", () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "token-at-render";
    document.head.append(meta);
    const { container } = render(<BootstrapMethodChoice {...props} />);
    const token = container.querySelector<HTMLInputElement>('input[name="authenticity_token"]');

    expect(token?.value).toBe("");

    meta.content = "token-at-submit";
    fireEvent.submit(screen.getByRole("button", { name: "Email" }));

    expect(token?.value).toBe("token-at-submit");
  });

  it("cancels through a link to Base and never through the form", () => {
    render(<BootstrapMethodChoice {...props} />);

    expect(screen.getByRole("link", { name: "Cancel" }).getAttribute("href")).toBe(
      "/identity?ri=jp",
    );
  });
});
