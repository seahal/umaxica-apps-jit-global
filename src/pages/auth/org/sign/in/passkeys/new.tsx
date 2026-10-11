// The passkey stage of normal operator sign-in.
//
// Entra ID already identified the operator, so the panel asks for no identifier: the server reads
// the actor from its own pending Entra transaction. The secret link is the documented fallback for
// a lost passkey, and it continues the same transaction rather than starting a new ceremony.
import Page from "@/components/ui/Page";
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type OrgPasskeySignInPageProps = {
  title: string;
  description: string;
  panel: PasskeyAuthenticationPanelProps;
  secret_link: { label: string; href: string };
  back_link: { label: string; href: string };
};

export default function OrgPasskeySignInPage({
  title,
  description,
  panel,
  secret_link: secretLink,
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

      <p className="mt-6 text-sm">
        <a
          href={secretLink.href}
          className="text-fg-muted underline underline-offset-4 hover:text-fg"
        >
          {secretLink.label}
        </a>
      </p>
    </Page>
  );
}
