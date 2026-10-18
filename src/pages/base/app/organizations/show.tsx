import NavList, { type NavListItem } from "@/components/ui/NavList";
import Page, { type PageUpLink } from "@/components/ui/Page";

type Props = { title: string; body: string; up_link: PageUpLink; links: NavListItem[] };

export default function OrganizationShow({ title, body, up_link: upLink, links }: Props) {
  return (
    <Page
      title={title}
      description={body}
      up={upLink}
      upVisit="inertia"
    >
      <NavList
        items={links}
        visit="inertia"
      />
    </Page>
  );
}
