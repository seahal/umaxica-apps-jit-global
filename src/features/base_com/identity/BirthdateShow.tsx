import Page from "@/components/ui/Page";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/birthdates/show.html.erb`.

export type BirthdateShowProps = {
  title: string;
  description: string;
  back_link: PageLink;
  birthdate_label: string;
  birthdate: string | null;
  not_set: string;
  change_unavailable: string;
};

export default function BirthdateShow({
  title,
  description,
  back_link: backLink,
  birthdate_label: birthdateLabel,
  birthdate,
  not_set: notSet,
  change_unavailable: changeUnavailable,
}: BirthdateShowProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      upVisit="inertia"
    >
      <dl className="flex flex-col gap-1 rounded-lg border border-line bg-surface p-4">
        <dt className="text-base font-medium text-fg-muted">{birthdateLabel}</dt>
        <dd className="text-base text-fg">
          {birthdate ? <span data-birthdate>{birthdate}</span> : notSet}
        </dd>
      </dl>

      <p className="text-base text-fg-muted">{changeUnavailable}</p>
    </Page>
  );
}
