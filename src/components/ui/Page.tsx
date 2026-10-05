// The one page shell.
//
// Before this component every page built its own: an outer `<section>` with a hand-picked
// `max-w-*`, its own padding, its own `<header>`, and an `<h1>` whose classes were copied from
// whichever page was open at the time. Five different content widths were in use for the same kind
// of screen, and the padding was applied twice — once by `SurfaceLayout`'s `<main>` and again by
// the page inside it.
//
// `docs/design.md` already states the hierarchy every page follows — Up, Title, Description, Body.
// This component is that hierarchy expressed once, so a page declares what it is rather than how
// wide it should be.
import { Link } from "@inertiajs/react";
import type { ReactNode } from "react";

/**
 * The content width scale. Three steps, chosen by what the page holds rather than by how much copy
 * it happens to have today:
 *
 * - `narrow` a single-purpose ceremony: one field, one button, one decision
 * - `default` the ordinary page — a form, a short list, a settings panel
 * - `wide`    tabular data and multi-column content that a narrower column would force to scroll
 */
export type PageWidth = "narrow" | "default" | "wide";

const WIDTHS: Record<PageWidth, string> = {
  narrow: "max-w-md",
  default: "max-w-2xl",
  wide: "max-w-4xl",
};

export type PageUpLink = {
  label: string;
  href: string;
};

/**
 * How following the up link navigates.
 *
 * `document` is the default because a ceremony's parent screen usually sits on another surface, and
 * an Inertia visit to another origin is an XHR that CORS rejects. `inertia` is for the parent that
 * genuinely lives on this surface, where a client-side visit keeps the chrome mounted.
 */
export type PageUpVisit = "document" | "inertia";

export type PageProps = {
  /** The page's `<h1>`. Omitted only by a page that renders its own heading, such as the landing. */
  title?: string;
  /** One or two lines saying what the page is for. */
  description?: string;
  /** The link to the parent screen, rendered above the title. */
  up?: PageUpLink | null;
  upVisit?: PageUpVisit;
  /** Controls that belong to the page as a whole, rendered opposite the title. */
  actions?: ReactNode;
  width?: PageWidth;
  /** Absent on a page whose whole content is its heading and description. */
  children?: ReactNode;
};

export default function Page({
  title,
  description,
  up = null,
  upVisit = "document",
  actions,
  width = "default",
  children,
}: PageProps) {
  const UP_CLASS =
    "ui-text-link inline-flex w-fit items-center gap-1 text-base text-fg-muted hover:text-fg";

  // The arrow is decorative: the label already says where the link goes, so announcing "left arrow"
  // in front of it would only add noise.
  const upBody = (
    <>
      <span aria-hidden="true">&larr;</span>
      <span className="ui-link-label">{up?.label}</span>
    </>
  );

  const upLink = up ? (
    upVisit === "inertia" ? (
      <Link
        href={up.href}
        className={UP_CLASS}
      >
        {upBody}
      </Link>
    ) : (
      <a
        href={up.href}
        className={UP_CLASS}
      >
        {upBody}
      </a>
    )
  ) : null;

  return (
    <div className={`mx-auto flex w-full flex-col gap-8 ${WIDTHS[width]}`}>
      {upLink || title || description || actions ? (
        <header className="flex flex-col gap-3">
          {upLink}

          <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
            {title ? (
              <h1 className="min-w-0 wrap-anywhere text-2xl leading-snug font-semibold text-balance text-fg sm:text-3xl">
                {title}
              </h1>
            ) : null}

            {actions ? (
              <div className="flex min-w-0 flex-wrap items-center gap-2">{actions}</div>
            ) : null}
          </div>

          {description ? (
            <p className="ui-prose text-base text-pretty text-fg-muted">{description}</p>
          ) : null}
        </header>
      ) : null}

      {children}
    </div>
  );
}
