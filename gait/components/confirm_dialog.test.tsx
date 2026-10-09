import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

// The shared confirmation the destructive actions go through. Every string it shows is a prop, so
// these tests assert the copy travels through untouched and that the action fires only on accept.
//
// The dialog is a React Aria `Modal`, so the assertions below are about behaviour a visitor can
// observe — what is announced, where focus sits, what Escape does — rather than about which element
// it renders. That is the point of the migration: the previous native `<dialog>` had no focus trap
// and no Escape under jsdom, so those properties could not be tested at all.
const { useConfirm } = await import("@/components/ConfirmDialog");

const accepted = vi.fn();

// `| undefined` is explicit because the harness forwards its own optional argument straight
// through, and under exactOptionalPropertyTypes a bare `cancelLabel?: string` would refuse that.
function Subject({ cancelLabel }: { cancelLabel?: string | undefined }) {
  const { confirm, dialog } = useConfirm();

  return (
    <div>
      <button
        type="button"
        onClick={() =>
          confirm(
            {
              message: "セッションを失効しますか？",
              confirmLabel: "失効",
              // Omitted rather than passed as undefined, which is what a screen whose props
              // carry no decline label actually sends.
              ...(cancelLabel === undefined ? {} : { cancelLabel }),
            },
            () => {
              accepted();
            },
          )
        }
      >
        revoke
      </button>
      {dialog}
    </div>
  );
}

const openDialog = async (cancelLabel?: string) => {
  const user = userEvent.setup();
  render(<Subject cancelLabel={cancelLabel} />);
  await user.click(screen.getByRole("button", { name: "revoke" }));
  return user;
};

describe("ConfirmDialog", () => {
  it("stays closed until a confirmation is pending", () => {
    render(<Subject />);

    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("is named by the server's confirmation copy", async () => {
    await openDialog();

    expect(screen.getByRole("dialog", { name: "セッションを失効しますか？" })).toBeTruthy();
  });

  it("runs the action only once the actor accepts", async () => {
    const user = await openDialog();
    accepted.mockClear();

    await user.click(screen.getByRole("button", { name: "失効" }));

    expect(accepted).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("runs nothing when the actor declines", async () => {
    const user = await openDialog("やめる");
    accepted.mockClear();

    await user.click(screen.getByRole("button", { name: "やめる" }));

    expect(accepted).not.toHaveBeenCalled();
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("closes on Escape without running the action", async () => {
    const user = await openDialog();
    accepted.mockClear();

    await user.keyboard("{Escape}");

    expect(accepted).not.toHaveBeenCalled();
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("shows the server's decline label when the screen carries one", async () => {
    await openDialog("やめる");

    expect(screen.getByRole("button", { name: "やめる" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "失効" })).toBeTruthy();
  });

  it("moves focus into the dialog, onto declining, which is the safe answer", async () => {
    await openDialog("やめる");

    expect(document.activeElement).toBe(screen.getByRole("button", { name: "やめる" }));
  });

  it("keeps Tab inside the dialog", async () => {
    const user = await openDialog("やめる");
    const decline = screen.getByRole("button", { name: "やめる" });
    const confirm = screen.getByRole("button", { name: "失効" });

    await user.tab();
    expect(document.activeElement).toBe(confirm);

    // The trap is the property the native <dialog> fallback never had: tabbing past the last
    // control returns to the first rather than escaping to the page behind.
    await user.tab();
    expect(document.activeElement).toBe(decline);
  });

  it("hides the page behind it from assistive technology", async () => {
    await openDialog();

    // Queried through the DOM rather than by role: the trigger is deliberately no longer in the
    // accessibility tree, which is the property under test.
    const trigger = document.querySelector("button");

    expect(trigger?.textContent).toBe("revoke");
    expect(trigger?.closest("[aria-hidden='true']")).toBeTruthy();
    expect(screen.queryByRole("button", { name: "revoke" })).toBeNull();
  });
});
