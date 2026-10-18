// The passkey step-up challenge for an already signed-in operator.
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type OrgVerificationPasskeyPageProps = {
  title: string;
  description: string;
  errors_sentence: string | null;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
  cancel: CeremonyCancellationProps;
};

export default function OrgVerificationPasskeyPage({
  title,
  description,
  errors_sentence: errorsSentence,
  panel,
  back_link: backLink,
  cancel,
}: OrgVerificationPasskeyPageProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <ErrorList errors={errorsSentence === null ? [] : [errorsSentence]} />

      <PasskeyAuthenticationPanel {...panel} />
      {/* Back returns to method selection; this ends the whole Step-Up ceremony. */}
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
