import { Link } from "@inertiajs/react";

// A self-service index listing. The server decides which entries exist and where each one links,
// so the component only renders what the props already resolved.
import Page, { type PageUpLink } from "@/components/ui/Page";

export type EntityListEntry = {
  public_id: string;
  label: string;
  href: string;
};

export type EntityListProps = {
  title: string;
  body: string;
  empty: string;
  entries: EntityListEntry[];
  up_link?: PageUpLink | null;
};

export default function EntityList({
  title,
  body,
  empty,
  entries,
  up_link: upLink = null,
}: EntityListProps) {
  // The surface Inertia layout owns the <main> landmark, so the page renders a section only.
  return (
    <Page
      title={title}
      description={body}
      up={upLink}
      upVisit="inertia"
    >
      {entries.length === 0 ? (
        <p className="text-sm text-fg-muted">{empty}</p>
      ) : (
        <ul className="flex flex-col gap-2 rounded-lg border border-line bg-surface p-2">
          {entries.map((entry) => (
            <li key={entry.public_id}>
              <Link
                href={entry.href}
                className="block rounded-md px-3 py-2 text-sm text-fg hover:bg-surface-muted hover:underline"
              >
                {entry.label}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Page>
  );
}
