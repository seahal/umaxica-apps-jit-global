// A bordered surface panel, with the section heading it usually carries.
//
// `rounded-lg border border-line bg-surface p-4` was written out in forty places, drifting a little
// each time — `p-2`, `px-4 py-3`, `bg-surface-muted`, sometimes with `text-sm` folded in. One
// component removes the drift and gives the heading a single treatment.
import { useId, type ReactNode } from "react";

export type CardTone = "default" | "muted";

const TONES: Record<CardTone, string> = {
  default: "bg-surface",
  muted: "bg-surface-muted",
};

export type CardProps = {
  /** Rendered as the panel's `<h2>`. A card without one is a plain container. */
  heading?: string;
  /** Controls belonging to the panel, rendered opposite the heading. */
  actions?: ReactNode;
  tone?: CardTone;
  className?: string;
  children: ReactNode;
};

export default function Card({
  heading,
  actions,
  tone = "default",
  className,
  children,
}: CardProps) {
  const headingId = useId();
  const Container = heading ? "section" : "div";
  return (
    <Container
      aria-labelledby={heading ? headingId : undefined}
      className={[
        "flex flex-col gap-4 rounded-xl border p-5",
        TONES[tone],
        heading ? "border-control" : "border-line",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {heading || actions ? (
        <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
          {heading ? (
            <h2
              id={headingId}
              className="min-w-0 wrap-anywhere text-xl leading-snug font-semibold text-fg"
            >
              {heading}
            </h2>
          ) : null}

          {actions ? (
            <div className="flex min-w-0 flex-wrap items-center gap-2">{actions}</div>
          ) : null}
        </div>
      ) : null}

      {children}
    </Container>
  );
}
