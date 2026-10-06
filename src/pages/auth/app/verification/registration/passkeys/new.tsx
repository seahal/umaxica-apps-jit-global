import Page from "@/components/ui/Page";
import CeremonyCancellation, { type CeremonyCancellationProps } from "@/features/auth/CeremonyCancellation";
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";

type Props = {
  title: string;
  description: string;
  panel: PasskeyRegistrationPanelProps;
  cancel: CeremonyCancellationProps;
};

export default function NewPasskeyRegistration({ title, description, panel, cancel }: Props) {
  return (
    <Page title={title} description={description} width="narrow">
      <PasskeyRegistrationPanel {...panel} />
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
