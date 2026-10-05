// Registers a new passkey.
//
// The ceremony itself is the shared panel ported from `passkey_registration_controller.js`: it
// solves the invisible Turnstile challenge, asks the options endpoint for a challenge, runs
// `navigator.credentials.create` and posts the attestation to the verification endpoint. Every one
// of those endpoints is unchanged and still enforces its own guards.
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import PasskeyRegistrationPanel, {
  type PasskeyRegistrationPanelProps,
} from "@/features/auth/passkeys/PasskeyRegistrationPanel";
import type { SettingsLink } from "@/features/auth/settings/links";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  cancel_link: SettingsLink;
  panel: PasskeyRegistrationPanelProps;
};

export default function PasskeysNew({
  title,
  description,
  back_link: backLink,
  cancel_link: cancelLink,
  panel,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <PasskeyRegistrationPanel {...panel} />

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
