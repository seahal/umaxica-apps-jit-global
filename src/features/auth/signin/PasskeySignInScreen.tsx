import Page from "@/components/ui/Page";

// The passkey sign-in page: heading, the ceremony panel, and the way back out.
import PasskeySignInPanel, { type PasskeySignInPanelProps } from "./PasskeySignInPanel";
import type { SignInLink } from "./types";

export type PasskeySignInScreenProps = {
  title: string;
  description: string;
  panel: PasskeySignInPanelProps;
  back_link: SignInLink;
};

export default function PasskeySignInScreen({
  title,
  description,
  panel,
  back_link: backLink,
}: PasskeySignInScreenProps) {
  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <PasskeySignInPanel {...panel} />

      <p className="text-base">
        {/* Document visit: leaving the ceremony returns to the method selection page. */}
        <a
          href={backLink.href}
          className="ui-text-link text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
        >
          {backLink.label}
        </a>
      </p>
    </Page>
  );
}
