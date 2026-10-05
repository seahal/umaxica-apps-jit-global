import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

import type { SignOutLink } from "./SignOutConfirmation";

// Shown when the RP logout transaction could not be issued. The retry keeps the POST verb the
// sign-out route expects rather than degrading to a link.
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
  const form = useForm({});

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post(retry.action);
  };

  return (
    <Page
      title={heading}
      width="narrow"
    >
      <p className="text-base text-fg-muted">{description}</p>

      <form
        action={retry.action}
        method="post"
        onSubmit={submit}
      >
        <Button
          type="submit"
          isDisabled={form.processing}
        >
          {retry.label}
        </Button>
      </form>

      <p className="text-base">
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <TextLink href={homeLink.href}>{homeLink.label}</TextLink>
      </p>
    </Page>
  );
}
