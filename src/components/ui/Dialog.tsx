// The modal primitive.
//
// React Aria's `Modal` owns what a modal has to get right: it traps focus, restores it to whatever
// opened the dialog, closes on Escape, marks the rest of the page inert for assistive technology,
// and renders into a portal so no ancestor's overflow or stacking context can clip it.
//
// This replaces a native `<dialog>` that called `showModal()` when it existed and fell back to
// setting the `open` attribute when it did not. jsdom implements neither method, so every test ran
// the fallback: the behaviour under test had no focus trap, no Escape and no inertness, and was
// therefore not the behaviour that shipped. One implementation now runs in both places.
import type { ReactNode } from "react";
import {
  Dialog as AriaDialog,
  Modal as AriaModal,
  Heading,
  ModalOverlay,
  type ModalOverlayProps,
} from "react-aria-components";

export type DialogProps = Omit<ModalOverlayProps, "children"> & {
  /** The dialog's accessible name, rendered as its heading. */
  title: string;
  children: ReactNode;
};

export default function Dialog({ title, children, ...props }: DialogProps) {
  return (
    <ModalOverlay
      {...props}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
    >
      <AriaModal className="max-h-[calc(100dvh-2rem)] w-full max-w-md overflow-y-auto rounded-lg border border-overlay bg-surface">
        <AriaDialog className="flex flex-col gap-4 p-6 outline-hidden">
          <Heading
            // `slot="title"` is what React Aria uses to name the dialog, so the heading and the
            // accessible name cannot drift apart.
            slot="title"
            className="text-lg font-semibold text-fg"
          >
            {title}
          </Heading>
          {children}
        </AriaDialog>
      </AriaModal>
    </ModalOverlay>
  );
}
