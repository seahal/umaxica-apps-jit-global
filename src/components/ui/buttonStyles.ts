// The one button appearance, shared by the two things that wear it.
//
// `Button` is a React Aria button and reports its states as data attributes, so it styles hover
// through the plugin's `hovered:` variant. `ButtonLink` is an anchor — a destination, not an
// action — and has no such attribute, so it styles hover through CSS `hover:`. Everything else
// about the two is the same, and keeping the palette and the metrics here is what stops a link
// that "looks like a button" from slowly ceasing to.

export type ButtonVariant = "primary" | "secondary" | "danger" | "ghost";
export type ButtonSize = "sm" | "md";

/** Which hover mechanism the element supports. */
export type ButtonStateSource = "aria" | "css";

const BASE =
  "inline-flex items-center justify-center gap-2 min-w-11 rounded-md text-center whitespace-normal font-medium transition-colors " +
  "disabled:cursor-not-allowed disabled:opacity-50";

const SIZES: Record<ButtonSize, string> = {
  sm: "min-h-11 px-3 py-2 text-base",
  md: "min-h-12 px-4 py-2.5 text-base",
};

// Complete utility names keep every interaction state in Tailwind's per-surface build.
const VARIANTS: Record<ButtonVariant, { rest: string; aria: string; css: string }> = {
  primary: {
    rest: "bg-accent text-accent-fg",
    aria: "hovered:bg-accent-hover pressed:bg-accent-hover",
    css: "hover:bg-accent-hover active:bg-accent-hover",
  },
  secondary: {
    rest: "border border-control bg-surface text-fg",
    aria: "hovered:bg-surface-muted pressed:bg-surface-muted",
    css: "hover:bg-surface-muted active:bg-surface-muted",
  },
  danger: {
    rest: "bg-danger text-danger-fg",
    aria: "hovered:bg-danger-hover pressed:bg-danger-hover",
    css: "hover:bg-danger-hover active:bg-danger-hover",
  },
  ghost: {
    rest: "text-fg",
    aria: "hovered:bg-surface-muted pressed:bg-surface-muted",
    css: "hover:bg-surface-muted active:bg-surface-muted",
  },
};

export function buttonClass(
  variant: ButtonVariant,
  size: ButtonSize,
  states: ButtonStateSource,
): string {
  const appearance = VARIANTS[variant];
  return `${BASE} ${SIZES[size]} ${appearance.rest} ${appearance[states]}`;
}
