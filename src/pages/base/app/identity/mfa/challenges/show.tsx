import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  reset_unavailable: string;
  toggle_title: string;
  state_label: string;
  back_link: IdentityLink;
  error: string | null;
};

export default function MfaChallengeShow({
  title,
  reset_unavailable: resetUnavailable,
  toggle_title: toggleTitle,
  state_label: stateLabel,
  back_link: backLink,
  error,
}: Props) {
  return (
    <Page
      title={title}
      description={resetUnavailable}
      up={backLink}
      width="narrow"
    >
      <ErrorList errors={error === null ? [] : [error]} />

      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3 text-base">
          <span className="font-medium text-fg">{toggleTitle}</span>
          <span className="text-fg-muted">{stateLabel}</span>
        </div>
      </Card>
    </Page>
  );
}
