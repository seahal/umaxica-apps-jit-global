import Page from "@/components/ui/Page";
// Starts the WebAuthn registration ceremony for a new passkey.
//
// The ceremony itself is the shared panel ported from the Stimulus controller; this screen only
// frames it with the copy and the way back that the server resolved.
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";

export type PasskeyNewProps = {
  title: string;
  description: string;
  panel: PasskeyRegistrationPanelProps;
  cancel_link: { label: string; href: string };
};

export default function PasskeyNew({
  title,
  description,
  panel,
  cancel_link: cancelLink,
}: PasskeyNewProps) {
  return (
    <Page
      title={title}
      description={description}
    >
      <PasskeyRegistrationPanel {...panel} />

      <a
        href={cancelLink.href}
        className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
      >
        {cancelLink.label}
      </a>
    </Page>
  );
}
