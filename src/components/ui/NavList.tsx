// A vertical list of destinations, each one a full-width row.
//
// This is the shape most screens in the application actually are: pick a sign-in method, pick a
// verification factor, pick a settings screen, pick a preference. It was written out separately
// every time and had already drifted — `rounded-md` here, `rounded-lg` there, `py-2` against
// `py-3` — so the same list of choices looked subtly different on each surface.
//
// A row whose `href` is null renders as text rather than a link. The dashboards use that for a
// ceremony the visitor cannot start from here, and the alternative — omitting it — would hide from
// the visitor that the ceremony exists at all.
import { Link } from "@inertiajs/react";

/** Whether following a row is a client-side visit or a document load. See `Page`'s `upVisit`. */
export type NavListVisit = "document" | "inertia";

export type NavListItem = {
  label: string;
  href: string | null;
  /** A second line under the label, when the label alone does not say where the row goes. */
  description?: string;
};

const ROW =
  "flex items-center justify-between gap-3 rounded-md border border-line bg-surface " +
  "min-h-12 px-4 py-3 text-base text-fg";

export default function NavList({
  items,
  visit = "document",
  label,
}: {
  items: NavListItem[];
  visit?: NavListVisit;
  /** Names the list for assistive technology when no heading above it does. */
  label?: string;
}) {
  return (
    <ul
      {...(label === undefined ? {} : { "aria-label": label })}
      className="flex flex-col gap-2"
    >
      {items.map((item) => {
        const body = (
          <>
            <span className="flex min-w-0 flex-col gap-0.5">
              <span className="ui-link-label font-medium">{item.label}</span>
              {item.description ? (
                <span className="shrink-0 text-fg-muted">{item.description}</span>
              ) : null}
            </span>
            <span
              aria-hidden="true"
              className="shrink-0 text-fg-muted"
            >
              &rarr;
            </span>
          </>
        );

        return (
          <li key={item.label}>
            {item.href === null ? (
              <span className={`${ROW} text-fg-muted`}>
                <span className="flex min-w-0 flex-col gap-0.5">
                  <span className="font-medium">{item.label}</span>
                  {item.description ? <span>{item.description}</span> : null}
                </span>
              </span>
            ) : visit === "inertia" ? (
              <Link
                href={item.href}
                className={`ui-text-link ${ROW} hover:bg-surface-muted`}
              >
                {body}
              </Link>
            ) : (
              <a
                href={item.href}
                className={`ui-text-link ${ROW} hover:bg-surface-muted`}
              >
                {body}
              </a>
            )}
          </li>
        );
      })}
    </ul>
  );
}
