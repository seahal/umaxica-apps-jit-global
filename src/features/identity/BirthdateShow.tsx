// The read-only birthdate screen. The date is already formatted by the server, and `birthdate` is
// null when none is recorded rather than the client deciding what "unset" looks like.
import Page from "@/components/ui/Page";

export type BirthdateShowProps = {
  title: string;
  description: string;
  birthdate_label: string;
  birthdate: string | null;
  not_set: string;
  change_unavailable: string;
  back_link: { label: string; href: string };
};

export default function BirthdateShow({
  title,
  description,
  birthdate_label: birthdateLabel,
  birthdate,
  not_set: notSet,
  change_unavailable: changeUnavailable,
  back_link: backLink,
}: BirthdateShowProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      upVisit="inertia"
      width="narrow"
    >
      <dl className="rounded-lg border border-line bg-surface p-4">
        <dt className="text-base font-semibold tracking-wide text-fg-muted uppercase">
          {birthdateLabel}
        </dt>
        <dd className="mt-1 text-base text-fg">
          {birthdate ? <span data-birthdate>{birthdate}</span> : notSet}
        </dd>
      </dl>

      <p className="text-base text-fg-muted">{changeUnavailable}</p>
    </Page>
  );
}
