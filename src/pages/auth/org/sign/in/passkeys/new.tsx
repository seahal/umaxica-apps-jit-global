// The passkey stage of normal operator sign-in.
//
// Entra ID already identified the operator, so the panel asks for no identifier: the server reads
// the actor from its own pending Entra transaction.
import Page from "@/components/ui/Page";
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type OrgPasskeySignInPageProps = {
  title: string;
  description: string;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
};

export default function OrgPasskeySignInPage({
  title,
  description,
  panel,
  back_link: backLink,
}: OrgPasskeySignInPageProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <PasskeyAuthenticationPanel {...panel} />

    </Page>
  );
}
