import Card from "@/components/ui/Card";
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

// The entry screen of the step-up verification ceremony: pick a second factor.
//
// The server decided which factors this actor holds, so `methods` is already filtered and each
// entry carries a finished label and a finished URL. When none is available it sends the notice
// instead, and the screen offers no way into a ceremony the guards would reject.
import type { VerificationMethodLink } from "./types";

export type VerificationEntryProps = {
  title: string;
  heading: string;
  section_title: string;
  description: string;
  methods: VerificationMethodLink[];
  no_methods_notice: string | null;
  notice: string | null;
  cancel: CeremonyCancellationProps;
};

export default function VerificationEntry({
  heading,
  section_title: sectionTitle,
  description,
  methods,
  no_methods_notice: noMethodsNotice,
  notice,
  cancel,
}: VerificationEntryProps) {
  return (
    <Page title={heading}>
      {notice ? (
        <p
          data-test-id="verification-notice"
          className="rounded-md border border-line bg-surface-muted p-3 text-sm text-fg"
        >
          {notice}
        </p>
      ) : null}

      <Card heading={sectionTitle}>
        <p className="text-sm text-fg-muted">{description}</p>

        {noMethodsNotice ? (
          <p
            data-test-id="verification-no-methods"
            className="text-sm text-fg-muted"
          >
            {noMethodsNotice}
          </p>
        ) : (
          /* Document visits: each factor ceremony runs behind its own guards. */
          <NavList items={methods} />
        )}
      </Card>
      {/* Ends the whole Step-Up ceremony; the server decides where the actor lands. */}
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
