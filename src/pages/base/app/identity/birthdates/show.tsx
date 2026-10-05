import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  change_unavailable: string;
  birthdate_label: string;
  not_set_label: string;
  birthdate: string | null;
  back_link: IdentityLink;
};

export default function BirthdateShow({
  title,
  description,
  change_unavailable: changeUnavailable,
  birthdate_label: birthdateLabel,
  not_set_label: notSetLabel,
  birthdate,
  back_link: backLink,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <Card>
        <dl className="flex flex-col gap-1">
          <dt className="text-base font-semibold tracking-wide text-fg-muted uppercase">
            {birthdateLabel}
          </dt>
          <dd className="text-base text-fg">
            {birthdate ? <span data-birthdate>{birthdate}</span> : notSetLabel}
          </dd>
        </dl>
      </Card>

      <p className="text-base text-fg-muted">{changeUnavailable}</p>
    </Page>
  );
}
