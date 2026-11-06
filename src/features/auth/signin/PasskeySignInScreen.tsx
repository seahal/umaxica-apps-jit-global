import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

// The passkey sign-in page: heading, the ceremony panel, and the way back out.
import PasskeySignInPanel, { type PasskeySignInPanelProps } from "./PasskeySignInPanel";
import type { SignInLink } from "./types";

export type PasskeySignInScreenProps = {
  title: string;
  description: string;
  panel: PasskeySignInPanelProps;
  back_link: SignInLink;
  cancel?: CeremonyCancellationProps | null;
};

export default function PasskeySignInScreen({
  title,
  description,
  panel,
  back_link: backLink,
  cancel,
}: PasskeySignInScreenProps) {
  return (
    <Page
      title={title}
      up={backLink}
      description={description}
      width="narrow"
    >
      <PasskeySignInPanel {...panel} />

      {cancel ? <CeremonyCancellation {...cancel} /> : null}
    </Page>
  );
}
