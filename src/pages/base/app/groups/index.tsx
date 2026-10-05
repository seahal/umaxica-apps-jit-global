import Page, { type PageUpLink } from "@/components/ui/Page";

type GroupsPageProps = {
  title: string;
  empty_message: string;
  up_link?: PageUpLink | null;
  groups: { public_id: string; name: string; href: string }[];
};

export default function GroupsIndex({
  title,
  groups,
  empty_message: emptyMessage,
  up_link: upLink = null,
}: GroupsPageProps) {
  return (
    <Page
      title={title}
      width="wide"
      up={upLink}
      upVisit="inertia"
    >
      {groups.length === 0 ? (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {groups.map((group) => (
            <li key={group.public_id}>
              <a
                href={group.href}
                className="text-fg underline underline-offset-4"
              >
                {group.name}
              </a>
            </li>
          ))}
        </ul>
      )}
    </Page>
  );
}
