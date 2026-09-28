// The screen an operator reaches when step-up is required but no method is configured yet. No
// earlier step-up state exists, so there is no Back: the only exit is cancelling the ceremony.
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

export type OrgVerificationSetupProps = {
  title: string;
  description: string;
  cancel: CeremonyCancellationProps;
  methods: { key: string; label: string; href: string }[];
};

export default function OrgVerificationSetup({
  title,
  description,
  cancel,
  methods,
}: OrgVerificationSetupProps) {
  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <NavList items={methods} />
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
