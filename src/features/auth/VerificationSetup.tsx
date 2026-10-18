// The step-up setup screen: the actor has no usable verification method yet.
//
// Only the methods that are actually missing are offered, and the server decides which those are,
// so a method already configured is absent from `methods` rather than filtered in the browser. No
// earlier step-up state exists, so there is no Back: the only exit is cancelling the ceremony.
import NavList from "@/components/ui/NavList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

export type VerificationSetupLink = {
  key: string;
  label: string;
  href: string;
};

export type VerificationSetupProps = {
  title: string;
  description: string;
  cancel: CeremonyCancellationProps;
  methods: VerificationSetupLink[];
};

export default function VerificationSetup({
  title,
  description,
  cancel,
  methods,
}: VerificationSetupProps) {
  return (
    <Page
      title={title}
      description={description}
    >
      {/* Document visits: registration lives on the identity host for email. */}
      <NavList items={methods} />
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
