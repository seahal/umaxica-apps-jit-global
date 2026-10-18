import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

// The shared button. React Aria owns activation, so these assert the behaviour a visitor depends
// on — that every input modality reaches the action and that a disabled button reaches nothing —
// rather than which handlers are attached.
const { default: Button } = await import("@/components/ui/Button");

// The subject of the test below: a caller's own className callback, which React Aria invokes with
// the render state. It lives out here so the assertion body carries no branch of its own.
const classNameForState = ({ isDisabled }: { isDisabled: boolean }) =>
  isDisabled ? "opacity-0" : "w-full";

describe("Button", () => {
  it("defaults to a non-submitting button so it cannot post a form by accident", () => {
    render(<Button>Save</Button>);

    expect(screen.getByRole("button", { name: "Save" }).getAttribute("type")).toBe("button");
  });

  it("submits when asked to", () => {
    render(<Button type="submit">Save</Button>);

    expect(screen.getByRole("button", { name: "Save" }).getAttribute("type")).toBe("submit");
  });

  it("fires on a pointer press", async () => {
    const user = userEvent.setup();
    const pressed = vi.fn();
    render(<Button onPress={pressed}>Save</Button>);

    await user.click(screen.getByRole("button", { name: "Save" }));

    expect(pressed).toHaveBeenCalledTimes(1);
  });

  it.each(["{Enter}", " "])("fires on %s from the keyboard", async (key) => {
    const user = userEvent.setup();
    const pressed = vi.fn();
    render(<Button onPress={pressed}>Save</Button>);

    await user.tab();
    expect(document.activeElement).toBe(screen.getByRole("button", { name: "Save" }));

    await user.keyboard(key);

    expect(pressed).toHaveBeenCalledTimes(1);
  });

  it("is disabled to assistive technology and to the pointer at once", async () => {
    const user = userEvent.setup();
    const pressed = vi.fn();
    render(
      <Button
        isDisabled
        onPress={pressed}
      >
        Save
      </Button>,
    );

    const button = screen.getByRole("button", { name: "Save" });
    expect(button.hasAttribute("disabled")).toBe(true);

    await user.click(button);
    expect(pressed).not.toHaveBeenCalled();
  });

  it("skips a disabled button in the tab order", async () => {
    const user = userEvent.setup();
    render(
      <>
        <Button isDisabled>First</Button>
        <Button>Second</Button>
      </>,
    );

    await user.tab();

    expect(document.activeElement).toBe(screen.getByRole("button", { name: "Second" }));
  });

  it.each([
    ["primary", "bg-accent"],
    ["secondary", "bg-surface"],
    ["danger", "bg-danger"],
    ["ghost", "hovered:bg-surface-muted"],
  ] as const)("paints the %s variant from tokens, never a raw colour", (variant, token) => {
    render(<Button variant={variant}>Save</Button>);

    const { className } = screen.getByRole("button", { name: "Save" });
    expect(className).toContain(token);
    expect(className).not.toMatch(/#[0-9a-f]{3,8}\b/iu);
  });

  it.each([
    ["sm", "px-3"],
    ["md", "px-4"],
  ] as const)("applies the %s size from the spacing scale", (size, token) => {
    render(<Button size={size}>Save</Button>);

    expect(screen.getByRole("button", { name: "Save" }).className).toContain(token);
  });

  it("keeps a caller's own classes alongside the variant", () => {
    render(<Button className="w-full">Save</Button>);

    const { className } = screen.getByRole("button", { name: "Save" });
    expect(className).toContain("w-full");
    expect(className).toContain("bg-accent");
  });

  it("honours a caller's className function, which React Aria calls with the button state", () => {
    render(<Button className={classNameForState}>Save</Button>);

    expect(screen.getByRole("button", { name: "Save" }).className).toContain("w-full");
  });
});
