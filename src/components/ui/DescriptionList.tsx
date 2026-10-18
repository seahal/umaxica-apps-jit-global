// Term-and-value detail, the shape every "show" screen in the application is.
//
// A session's binding and expiry, a credential's created and last-used dates, a stored birthdate:
// six screens rendered this as a bare `<dl>` and the three that styled it each picked a different
// arrangement. The stacked-to-side-by-side behaviour is the part worth having in one place — the
// term column is fixed at the width a Japanese label needs, and collapses under it on a phone.
import type { ReactNode } from "react";

export type DescriptionListItem = {
  term: string;
  description: ReactNode;
};

export default function DescriptionList({ items }: { items: DescriptionListItem[] }) {
  return (
    <dl className="flex flex-col gap-3 text-base">
      {items.map((item) => (
        <div
          key={item.term}
          className="flex flex-col gap-1 sm:flex-row sm:gap-8"
        >
          <dt className="font-medium text-fg-muted sm:w-44 sm:shrink-0">{item.term}</dt>
          <dd className="min-w-0 wrap-anywhere text-fg">{item.description}</dd>
        </div>
      ))}
    </dl>
  );
}
