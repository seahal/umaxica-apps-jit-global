import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import Select from "@/components/ui/Select";

describe("Select", () => {
  it("uses the visible label for a native, keyboard reachable single select", async () => {
    const user = userEvent.setup();
    render(
      <Select
        label="Theme"
        options={[{ value: "system", label: "System" }]}
      />,
    );
    const select = screen.getByRole("combobox", { name: "Theme" });
    expect(select.tagName).toBe("SELECT");
    await user.tab();
    expect(document.activeElement).toBe(select);
    expect(screen.queryByRole("button")).toBeNull();
  });

  it("submits the original parameter name and reports a selected string value", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <form aria-label="Preferences">
        <Select
          label="Theme"
          name="preference_theme[option_id]"
          defaultValue="1"
          onChange={changed}
          options={[
            { value: "1", label: "System" },
            { value: "3", label: "Dark" },
          ]}
        />
      </form>,
    );
    await user.selectOptions(screen.getByRole("combobox"), "3");
    expect(changed).toHaveBeenLastCalledWith("3");
    expect(
      new FormData(screen.getByRole<HTMLFormElement>("form")).get("preference_theme[option_id]"),
    ).toBe("3");
  });

  it("keeps a stored disabled option selected without allowing a replacement selection", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <Select
        label="Theme"
        defaultValue="system"
        onChange={changed}
        options={[
          { value: "system", label: "System", isDisabled: true },
          { value: "light", label: "Light" },
        ]}
      />,
    );
    const option = screen.getByRole<HTMLOptionElement>("option", { name: "System" });
    expect(option.disabled).toBe(true);
    expect(option.selected).toBe(true);
    await user.selectOptions(screen.getByRole("combobox"), "system");
    expect(changed).not.toHaveBeenCalled();
  });

  it("preserves native disabled and required behavior and disabled form exclusion", async () => {
    const user = userEvent.setup();
    render(
      <form aria-label="Preferences">
        <Select
          label="Theme"
          name="theme"
          isDisabled
          isRequired
          options={[{ value: "light", label: "Light" }]}
        />
      </form>,
    );
    const select = screen.getByRole<HTMLSelectElement>("combobox");
    expect(select.disabled).toBe(true);
    expect(select.required).toBe(true);
    await user.tab();
    expect(document.activeElement).not.toBe(select);
    expect(new FormData(screen.getByRole<HTMLFormElement>("form")).has("theme")).toBe(false);
  });

  it("places conditions before input and associates both conditions and a static error", () => {
    render(
      <Select
        id="theme"
        label="Theme"
        description="Applies to this account."
        errorMessage="Not available."
        options={[{ value: "light", label: "Light" }]}
      />,
    );
    const select = screen.getByRole("combobox");
    const description = screen.getByText("Applies to this account.");
    const error = screen.getByText("Not available.");
    expect(
      description.compareDocumentPosition(select) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
    expect(select.getAttribute("aria-describedby")?.split(" ")).toEqual([description.id, error.id]);
    expect(select.getAttribute("aria-invalid")).toBe("true");
    expect(error.getAttribute("role")).toBeNull();
    expect(error.getAttribute("aria-live")).toBeNull();
    expect(select.id).toBe("theme");
  });

  it.each(["", "0", "\u0000"])(
    "retains the supplied sentinel option value %j without inventing choices",
    (value) => {
      render(
        <form aria-label="Preferences">
          <Select
            label="Choice"
            name="choice"
            value={value}
            onChange={() => {}}
            options={[{ value, label: "Supplied option" }]}
          />
        </form>,
      );
      expect(screen.getAllByRole("option")).toHaveLength(1);
      expect(new FormData(screen.getByRole<HTMLFormElement>("form")).get("choice")).toBe(value);
    },
  );

  it("renders empty choices without creating a selectable placeholder", () => {
    render(
      <Select
        label="Choice"
        options={[]}
      />,
    );
    expect(screen.getByRole("combobox").children).toHaveLength(0);
    expect(screen.queryByRole("option")).toBeNull();
    expect(screen.getByRole<HTMLSelectElement>("combobox").required).toBe(false);
  });
});
