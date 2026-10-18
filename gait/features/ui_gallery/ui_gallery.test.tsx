import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";

// The dev surface's primitives page. It ships only on `core/dev`, so this checks that every
// primitive it is meant to show up actually renders and that its one interactive control works.
const { UiGallery } = await import("@/features/ui_gallery/UiGallery");

describe("UiGallery", () => {
  it("names itself as internal", () => {
    render(<UiGallery />);

    expect(screen.getByRole("heading", { level: 1, name: "UI primitives" })).toBeTruthy();
    expect(screen.getByText(/dev surface only/iu)).toBeTruthy();
  });

  it("shows every button variant and a disabled one", () => {
    render(<UiGallery />);

    for (const variant of ["primary", "secondary", "danger", "ghost"]) {
      expect(screen.getByRole("button", { name: variant })).toBeTruthy();
    }

    expect(screen.getByRole<HTMLButtonElement>("button", { name: "disabled" }).disabled).toBe(true);
  });

  it("shows a field in each of its states", () => {
    render(<UiGallery />);

    expect(screen.getByLabelText("Address")).toBeTruthy();
    expect(screen.getByLabelText("Rejected address").getAttribute("aria-invalid")).toBe("true");
    expect(screen.getByLabelText<HTMLInputElement>("Disabled").disabled).toBe(true);
  });

  it("shows the select, the checkboxes and the radio group", () => {
    render(<UiGallery />);

    expect(screen.getByRole("combobox", { name: "Theme" })).toBeTruthy();
    expect(screen.getByRole("checkbox", { name: "Functional cookies" })).toBeTruthy();
    expect(screen.getByRole("radiogroup", { name: "Delivery" })).toBeTruthy();
  });

  it("opens and closes its dialog", async () => {
    const user = userEvent.setup();
    render(<UiGallery />);

    await user.click(screen.getByRole("button", { name: "Open the dialog" }));
    expect(screen.getByRole("dialog")).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Close" }));
    expect(screen.queryByRole("dialog")).toBeNull();
  });
});
