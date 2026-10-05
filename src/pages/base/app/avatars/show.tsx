import ButtonLink from "@/components/ui/ButtonLink";
import Page, { type PageUpLink } from "@/components/ui/Page";

type Props = {
  title: string;
  up_link?: PageUpLink | null;
  moniker: string;
  handle: string | null;
  // The server omits the link when the actor may not edit the avatar.
  edit: { label: string; href: string } | null;
};

export default function AvatarShow({ moniker, handle, edit, up_link: upLink = null }: Props) {
  return (
    <Page
      title={moniker}
      up={upLink}
      upVisit="inertia"
      {...(handle === null ? {} : { description: handle })}
      width="narrow"
      {...(edit === null
        ? {}
        : {
            actions: (
              <ButtonLink
                href={edit.href}
                variant="secondary"
                size="sm"
                inertia
              >
                {edit.label}
              </ButtonLink>
            ),
          })}
    />
  );
}
