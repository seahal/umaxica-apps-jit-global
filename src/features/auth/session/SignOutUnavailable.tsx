import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import { csrfToken } from "@/lib/csrf";

import type { SignOutLink } from "./SignOutConfirmation";

// Shown when the RP logout transaction could not be issued. The retry keeps the POST verb the
// sign-out route expects rather than degrading to a link, and is a full document submission for the
// same cross-origin redirect reason as the confirmation.
export type SignOutUnavailableProps = {
  title: string;
  heading: string;
  description: string;
  retry: {
    label: string;
    action: string;
  };
  home_link: SignOutLink;
};

export default function SignOutUnavailable({
  heading,
  description,
  retry,
  home_link: homeLink,
}: SignOutUnavailableProps) {
  return (
    <Page
      title={heading}
      width="narrow"
    >
      <p className="text-base text-fg-muted">{description}</p>

      <form
        action={retry.action}
        method="post"
        data-turbo="false"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />
        <Button type="submit">{retry.label}</Button>
      </form>

      <p className="text-base">
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <TextLink href={homeLink.href}>{homeLink.label}</TextLink>
      </p>
    </Page>
  );
}
