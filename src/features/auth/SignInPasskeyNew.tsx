import Page from "@/components/ui/Page";
// Sign in with a passkey.
//
// The ceremony is the shared panel ported from the Stimulus controller; this screen frames it with
// the copy and the way back that the server resolved.
import PasskeyAuthenticationPanel, {
  type PasskeyAuthenticationPanelProps,
} from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

export type SignInPasskeyNewProps = {
  title: string;
  description: string;
  panel: PasskeyAuthenticationPanelProps;
  back_link: { label: string; href: string };
};

export default function SignInPasskeyNew({
  title,
  description,
  panel,
  back_link: backLink,
}: SignInPasskeyNewProps) {
  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <PasskeyAuthenticationPanel {...panel} />

      <a
        href={backLink.href}
        className="ui-text-link text-base text-fg underline underline-offset-4 hover:underline"
      >
        {backLink.label}
      </a>
    </Page>
  );
}
