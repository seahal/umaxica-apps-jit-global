// A labelled checkbox.
//
// React Aria renders a real `<input type="checkbox">` inside the button's label, so the control
// keeps native semantics and form participation, and adds the hover, press, focus and
// indeterminate states as data attributes. The visible box below is a `<div>` on purpose: it is
// decorative, and the input React Aria hides is what assistive technology reads.
//
// `CheckboxField` owns the state and `CheckboxButton` is the clickable area; the bare `Checkbox`
// that combined the two is deprecated in react-aria-components 1.20.
import type { ReactNode } from "react";
import { CheckboxButton, CheckboxField, type CheckboxFieldProps } from "react-aria-components";

export type CheckboxProps = Omit<CheckboxFieldProps, "children"> & {
  children: ReactNode;
};

export default function Checkbox({ children, ...props }: CheckboxProps) {
  return (
    <CheckboxField {...props}>
      <CheckboxButton
        className="ui-choice-target group flex min-h-11 items-center gap-2 py-2 text-base text-fg disabled:cursor-not-allowed
          disabled:opacity-50"
      >
        <div
          aria-hidden="true"
          className="flex size-4 shrink-0 items-center justify-center rounded-sm border border-control
            bg-surface transition-colors group-selected:border-accent group-selected:bg-accent
            group-indeterminate:border-accent group-indeterminate:bg-accent"
        >
          <span className="text-xs leading-none text-accent-fg opacity-0 group-selected:opacity-100">
            ✓
          </span>
        </div>
        {children}
      </CheckboxButton>
    </CheckboxField>
  );
}
