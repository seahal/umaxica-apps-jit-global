// Emergency Access (Restricted Mode) sign-in for operators.
//
// It is identifier-first, unlike the normal passkey stage: no earlier stage has selected the
// operator, because Emergency Access exists for when Entra ID is not usable. The ceremony below is
// the same shared panel and the same server implementation as normal sign-in; only the endpoints,
// the challenge purpose behind them, and the session it produces differ.
//
// The notice is not a warning decoration: it is the one place before the ceremony where the
// operator learns that the session they are about to create cannot perform step-up verification.
import Page from "@/components/ui/Page";
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type OrgEmergencyPasskeySignInPageProps = {
  title: string;
  description: string;
  restricted_mode_notice: string;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
};

export default function OrgEmergencyPasskeySignInPage({
  title,
  description,
  restricted_mode_notice: restrictedModeNotice,
  panel,
  back_link: backLink,
}: OrgEmergencyPasskeySignInPageProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <p className="mb-6 rounded-md border border-line bg-surface-muted px-3 py-2 text-sm text-fg">
        {restrictedModeNotice}
      </p>

      <PasskeyAuthenticationPanel {...panel} />
    </Page>
  );
}
