// Answering the shared destructive-action confirmation from a spec.
//
// The confirmation is a React Aria `Modal`, which changes two things every spec that drives it had
// hard-coded: it renders through a portal on `document.body` rather than inside the container the
// spec mounted, and it is a `role="dialog"` element rather than a native `<dialog open>`.
//
// Centralising the lookup keeps that knowledge in one place. Declining is first in DOM order and
// confirming second, which is the order `ConfirmDialog` renders them in.
import { act } from "react";

const dialog = (): HTMLElement | null => document.querySelector<HTMLElement>("[role='dialog']");

export const confirmationButtons = (): HTMLButtonElement[] => [
  ...(dialog()?.querySelectorAll("button") ?? []),
];

export const answerConfirmation = (accepted: boolean) => {
  const button = confirmationButtons()[accepted ? 1 : 0];
  act(() => {
    button?.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

/** Accepting, for the specs that only ever take the destructive branch. */
export const acceptConfirmation = () => answerConfirmation(true);
