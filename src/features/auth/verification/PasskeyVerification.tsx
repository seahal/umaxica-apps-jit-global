import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, { type CeremonyCancellationProps } from "@/features/auth/CeremonyCancellation";
import PasskeyAuthenticationPanel, { type PasskeyAuthenticationPanelProps } from "@/features/auth/passkeys/PasskeyAuthenticationPanel";
import type { VerificationLink } from "./types";

export type PasskeyVerificationProps = {
  title: string;
  heading: string;
  description: string;
  errors: string[];
  panel: PasskeyAuthenticationPanelProps;
  back: VerificationLink;
  cancel: CeremonyCancellationProps;
};

export default function PasskeyVerification({ heading, description, errors, panel, back, cancel }: PasskeyVerificationProps) {
  return (
    <Page title={heading} description={description} up={back} width="narrow">
      <ErrorList errors={errors} />
      <PasskeyAuthenticationPanel {...panel} />
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
