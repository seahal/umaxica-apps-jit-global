// Registering a new passkey for the operator.
//
// The whole ceremony is the JSON options/verification pair the Stimulus controller drove; the panel
// is its React port and talks to the same two endpoints behind the same step-up and Turnstile
// guards.
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";

export type OrgPasskeyRegistrationPageProps = {
  title: string;
  description: string;
  registration: PasskeyRegistrationPanelProps;
  cancel_link: { label: string; href: string };
};

export default function OrgPasskeyRegistrationPage({
  title,
  description,
  registration,
  cancel_link: cancelLink,
}: OrgPasskeyRegistrationPageProps) {
  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <PasskeyRegistrationPanel {...registration} />

      <p className="text-base">
        <TextLink
          href={cancelLink.href}
          tone="muted"
        >
          {cancelLink.label}
        </TextLink>
      </p>
    </Page>
  );
}
