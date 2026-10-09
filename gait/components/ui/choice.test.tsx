import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

// Checkbox and RadioGroup. The radio assertions cover the part a bare `<fieldset>` of native radios
// does not give for free: the group is one tab stop and the arrow keys move within it.
const { default: Checkbox } = await import("@/components/ui/Checkbox");
const { default: RadioGroup } = await import("@/components/ui/RadioGroup");

describe("Checkbox", () => {
  it("is a real checkbox named by its content", () => {
    render(<Checkbox>Functional cookies</Checkbox>);

    expect(screen.getByRole("checkbox", { name: "Functional cookies" })).toBeTruthy();
  });

  it("toggles with the Space key", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(<Checkbox onChange={changed}>Functional cookies</Checkbox>);

    await user.tab();
    await user.keyboard(" ");

    expect(changed).toHaveBeenLastCalledWith(true);
  });

  it("toggles on a pointer press", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(<Checkbox onChange={changed}>Functional cookies</Checkbox>);

    await user.click(screen.getByRole("checkbox", { name: "Functional cookies" }));

    expect(changed).toHaveBeenLastCalledWith(true);
  });

  it("reports a checked default", () => {
    render(<Checkbox defaultSelected>Functional cookies</Checkbox>);

    expect(
      screen.getByRole<HTMLInputElement>("checkbox", { name: "Functional cookies" }).checked,
    ).toBe(true);
  });

  it("cannot be toggled while disabled", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <Checkbox
        isDisabled
        onChange={changed}
      >
        Functional cookies
      </Checkbox>,
    );

    await user.click(screen.getByRole("checkbox", { name: "Functional cookies" }));

    expect(changed).not.toHaveBeenCalled();
  });

  it("reports the indeterminate state rather than guessing a value", () => {
    render(<Checkbox isIndeterminate>Functional cookies</Checkbox>);

    // A native checkbox carries this as a DOM property, which is what the accessibility tree reads;
    // there is no `aria-checked` attribute on a real `<input type="checkbox">`.
    const input = screen.getByRole<HTMLInputElement>("checkbox", { name: "Functional cookies" });
    expect(input.indeterminate).toBe(true);
  });
});

const RADIO_OPTIONS = [
  { value: "email", label: "Email", description: "The address on the account." },
  { value: "sms", label: "SMS" },
  { value: "none", label: "Nothing", isDisabled: true },
];

describe("RadioGroup", () => {
  it("names the group, not each option", () => {
    render(
      <RadioGroup
        label="Delivery"
        options={RADIO_OPTIONS}
      />,
    );

    expect(screen.getByRole("radiogroup", { name: "Delivery" })).toBeTruthy();
  });

  it("holds a single tab stop for the whole group", async () => {
    const user = userEvent.setup();
    render(
      <>
        <RadioGroup
          label="Delivery"
          defaultValue="email"
          options={RADIO_OPTIONS}
        />
        <button type="button">After</button>
      </>,
    );

    await user.tab();
    expect(document.activeElement).toBe(screen.getByRole("radio", { name: /Email/u }));

    // One more Tab leaves the group entirely rather than stepping to the next radio.
    await user.tab();
    expect(document.activeElement).toBe(screen.getByRole("button", { name: "After" }));
  });

  it("moves the selection with the arrow keys", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <RadioGroup
        label="Delivery"
        defaultValue="email"
        onChange={changed}
        options={RADIO_OPTIONS}
      />,
    );

    await user.tab();
    await user.keyboard("{ArrowDown}");

    expect(changed).toHaveBeenLastCalledWith("sms");
  });

  it("skips a disabled option when arrowing", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <RadioGroup
        label="Delivery"
        defaultValue="sms"
        onChange={changed}
        options={RADIO_OPTIONS}
      />,
    );

    await user.tab();
    await user.keyboard("{ArrowDown}");

    expect(changed).not.toHaveBeenLastCalledWith("none");
  });

  it("renders an option's own description", () => {
    render(
      <RadioGroup
        label="Delivery"
        options={RADIO_OPTIONS}
      />,
    );

    expect(screen.getByText("The address on the account.")).toBeTruthy();
  });

  it("shows the group's description and the server's message", () => {
    render(
      <RadioGroup
        label="Delivery"
        description="How the code reaches you."
        errorMessage="Pick one."
        options={RADIO_OPTIONS}
      />,
    );

    expect(screen.getByText("How the code reaches you.")).toBeTruthy();
    expect(screen.getByText("Pick one.")).toBeTruthy();
  });
});
