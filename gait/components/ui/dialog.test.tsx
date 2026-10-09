import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";

// The shared modal. Everything asserted here — the trap, the restore, Escape, the inert background
// — is React Aria's, and none of it was testable while the component drove a native `<dialog>`:
// jsdom implements neither `showModal()` nor `close()`, so the tests ran an unguarded fallback.
const { default: Dialog } = await import("@/components/ui/Dialog");

// `| undefined` is explicit because the harness forwards its own optional argument straight
// through, and under exactOptionalPropertyTypes a bare optional prop would refuse that.
function Subject({ onOpenChange }: { onOpenChange?: ((isOpen: boolean) => void) | undefined }) {
  const [isOpen, setOpen] = useState(false);

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen(true)}
      >
        Open
      </button>
      <Dialog
        title="Revoke the session?"
        isOpen={isOpen}
        onOpenChange={(next) => {
          setOpen(next);
          onOpenChange?.(next);
        }}
      >
        <button type="button">First</button>
        <button type="button">Second</button>
      </Dialog>
    </div>
  );
}

const open = async (onOpenChange?: (isOpen: boolean) => void) => {
  const user = userEvent.setup();
  render(<Subject onOpenChange={onOpenChange} />);
  await user.click(screen.getByRole("button", { name: "Open" }));
  return user;
};

describe("Dialog", () => {
  it("renders nothing while closed", () => {
    render(<Subject />);

    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("takes its accessible name from the heading, so the two cannot drift", async () => {
    await open();

    expect(screen.getByRole("dialog", { name: "Revoke the session?" })).toBeTruthy();
    expect(screen.getByRole("heading", { name: "Revoke the session?" })).toBeTruthy();
  });

  it("moves focus into the dialog on open", async () => {
    await open();

    expect(screen.getByRole("dialog").contains(document.activeElement)).toBe(true);
  });

  it("keeps Tab inside the dialog", async () => {
    const user = await open();
    const first = screen.getByRole("button", { name: "First" });
    const second = screen.getByRole("button", { name: "Second" });

    await user.tab();
    expect(document.activeElement).toBe(first);

    await user.tab();
    expect(document.activeElement).toBe(second);

    // Wraps rather than escaping to the page behind.
    await user.tab();
    expect(document.activeElement).toBe(first);
  });

  it("wraps backwards too", async () => {
    const user = await open();

    await user.tab();
    await user.tab({ shift: true });

    expect(screen.getByRole("dialog").contains(document.activeElement)).toBe(true);
  });

  it("closes on Escape", async () => {
    const changed = vi.fn();
    const user = await open(changed);

    await user.keyboard("{Escape}");

    expect(screen.queryByRole("dialog")).toBeNull();
    expect(changed).toHaveBeenLastCalledWith(false);
  });

  it("restores focus to whatever opened it", async () => {
    const user = await open();

    await user.keyboard("{Escape}");

    // React Aria restores focus after the overlay unmounts rather than in the same tick, so the
    // trigger is only queryable — and only focused — once that has settled.
    await waitFor(() => {
      expect(document.activeElement).toBe(screen.getByRole("button", { name: "Open" }));
    });
  });

  it("hides the rest of the page from assistive technology while it is open", async () => {
    await open();

    // Queried through the DOM: being absent from the accessibility tree is the point.
    const trigger = document.querySelector("button");
    expect(trigger?.textContent).toBe("Open");
    expect(screen.queryByRole("button", { name: "Open" })).toBeNull();
  });
});
