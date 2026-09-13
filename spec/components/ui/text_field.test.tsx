import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { describedByText } from "../../support/dom";

// The shared text input.
//
// The association assertions below are the reason this component exists: before it, no field in the
// application carried `aria-invalid` or pointed `aria-describedby` at its message, so a screen
// reader announced a rejected input with no indication that it was the one rejected.
const { default: TextField } = await import("@/components/ui/TextField");

describe("TextField", () => {
  it("ignores a function className rather than stringifying it", () => {
    render(
      <TextField
        label="Address"
        className={() => "from-render-props"}
      />,
    );

    expect(screen.getByLabelText("Address").closest("div")?.className).not.toContain(
      "from-render-props",
    );
  });

  it("gives the input its label without the caller building an id", () => {
    render(<TextField label="Address" />);

    expect(screen.getByLabelText("Address").tagName).toBe("INPUT");
  });

  it("renders a textarea when asked, still labelled", () => {
    render(
      <TextField
        label="Reason"
        multiline
      />,
    );

    expect(screen.getByLabelText("Reason").tagName).toBe("TEXTAREA");
  });

  it("is not marked invalid while the server has said nothing", () => {
    render(<TextField label="Address" />);

    expect(screen.getByLabelText("Address").getAttribute("aria-invalid")).not.toBe("true");
  });

  it("marks the input invalid and points it at the server's message", () => {
    render(
      <TextField
        label="Address"
        errorMessage="Already registered."
      />,
    );

    const input = screen.getByLabelText("Address");
    expect(input.getAttribute("aria-invalid")).toBe("true");

    // The association, not merely the presence of the text: the ids the input names must be the
    // ones the message actually carries.
    expect(describedByText(input)).toContain("Already registered.");
  });

  it("also associates a description, alongside any message", () => {
    render(
      <TextField
        label="Address"
        description="We send the code here."
        errorMessage="Already registered."
      />,
    );

    const described = describedByText(screen.getByLabelText("Address"));

    expect(described).toContain("We send the code here.");
    expect(described).toContain("Already registered.");
  });

  it("reports a required field to assistive technology", () => {
    render(
      <TextField
        label="Address"
        isRequired
      />,
    );

    // React Aria defaults to native validation, so the requirement is carried by the `required`
    // attribute rather than by `aria-required`. Both are announced; asserting the one actually
    // used keeps this test honest about the mechanism.
    expect(screen.getByLabelText<HTMLInputElement>("Address").required).toBe(true);
  });

  it("reports the value as the actor types", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <TextField
        label="Address"
        onChange={changed}
      />,
    );

    await user.type(screen.getByLabelText("Address"), "ab");

    // React Aria hands over the value itself rather than an event, so a caller never reads
    // `event.target.value`.
    expect(changed).toHaveBeenLastCalledWith("ab");
  });

  it("takes focus from the keyboard", async () => {
    const user = userEvent.setup();
    render(<TextField label="Address" />);

    await user.tab();

    expect(document.activeElement).toBe(screen.getByLabelText("Address"));
  });

  it("is skipped and unwritable while disabled", async () => {
    const user = userEvent.setup();
    render(
      <TextField
        label="Address"
        isDisabled
        defaultValue="fixed"
      />,
    );

    const input = screen.getByLabelText<HTMLInputElement>("Address");
    expect(input.disabled).toBe(true);

    await user.type(input, "more");
    expect(input.value).toBe("fixed");
  });

  it("carries the name the server's parameter wrapper expects", () => {
    render(
      <TextField
        label="Address"
        name="client[email]"
      />,
    );

    expect(screen.getByLabelText("Address").getAttribute("name")).toBe("client[email]");
  });

  it("forwards autoCapitalize onto the control when the field asks for it", () => {
    render(
      <TextField
        label="Operator"
        autoCapitalize="characters"
      />,
    );

    expect(screen.getByLabelText("Operator").getAttribute("autocapitalize")).toBe("characters");
  });
});
