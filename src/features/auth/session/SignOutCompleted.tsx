import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

import type { SignOutLink } from "./SignOutConfirmation";

// The sign-out completion notice. The description is optional: the server only sends it when it
// knows when the cleared access token stops being accepted.
export type SignOutCompletedProps = {
  title: string;
  heading: string;
  description: string | null;
  home_link: SignOutLink;
};

export default function SignOutCompleted({
  heading,
  description,
  home_link: homeLink,
}: SignOutCompletedProps) {
  return (
    <Page
      title={heading}
      width="narrow"
    >
      {description ? <p className="text-base text-fg-muted">{description}</p> : null}

      <p className="text-base">
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <TextLink href={homeLink.href}>{homeLink.label}</TextLink>
      </p>
    </Page>
  );
}
