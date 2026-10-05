import ButtonLink from "@/components/ui/ButtonLink";
import Page, { type PageUpLink } from "@/components/ui/Page";

type AvatarSummary = { moniker: string };
type ActionLink = { label: string; href: string };

type Props = {
  title: string;
  avatar: AvatarSummary | null;
  empty_message: string | null;
  action_link: ActionLink | null;
  switcher_link: ActionLink;
  up_link: PageUpLink;
};

export default function AvatarShow({
  title,
  avatar,
  empty_message: emptyMessage,
  action_link: actionLink,
  switcher_link: switcherLink,
  up_link: upLink,
}: Props) {
  const description = avatar?.moniker ?? emptyMessage;

  return (
    <Page
      title={title}
      {...(description === null ? {} : { description })}
      up={upLink}
    >
      {avatar && actionLink ? (
        <ButtonLink href={actionLink.href} variant="secondary" size="sm" inertia>
          {actionLink.label}
        </ButtonLink>
      ) : (
        <ButtonLink href={switcherLink.href} variant="secondary" size="sm" inertia>
          {switcherLink.label}
        </ButtonLink>
      )}
    </Page>
  );
}
