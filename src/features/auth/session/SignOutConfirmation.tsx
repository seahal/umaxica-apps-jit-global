import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

// The sign-out confirmation ceremony, shared by the auth surfaces.
//
// Sign-out is destructive, so both the confirmation and the cancellation keep the HTTP verbs the
// Rails routes expect (POST and DELETE). Nothing here is a link.
export type SignOutLink = {
  label: string;
  href: string;
};

export type SignOutConfirmationProps = {
  title: string;
  heading: string;
  active_context: boolean;
  confirm_description: string;
  already_signed_out: string;
  submit_label: string;
  form: {
    action: string;
    logout_challenge: string | null;
  };
  cancel: {
    label: string;
    action: string;
  };
  home_link: SignOutLink;
};

export default function SignOutConfirmation({
  heading,
  active_context: activeContext,
  confirm_description: confirmDescription,
  already_signed_out: alreadySignedOut,
  submit_label: submitLabel,
  form,
  cancel,
  home_link: homeLink,
}: SignOutConfirmationProps) {
  const confirmation = useForm({ logout_challenge: form.logout_challenge ?? "" });
  const cancellation = useForm({});

  const submitConfirmation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    confirmation.post(form.action);
  };

  const submitCancellation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    cancellation.delete(cancel.action);
  };

  return (
    <Page
      title={heading}
      width="narrow"
    >
      {activeContext ? (
        <>
          <p className="text-base text-fg-muted">{confirmDescription}</p>
          <div className="flex flex-wrap items-center gap-3">
            <form
              action={form.action}
              method="post"
              onSubmit={submitConfirmation}
            >
              <Button
                type="submit"
                variant="danger"
                isDisabled={confirmation.processing}
              >
                {submitLabel}
              </Button>
            </form>
            <form
              action={cancel.action}
              method="post"
              onSubmit={submitCancellation}
            >
              <input
                type="hidden"
                name="_method"
                value="delete"
              />
              <Button
                type="submit"
                variant="secondary"
                isDisabled={cancellation.processing}
              >
                {cancel.label}
              </Button>
            </form>
          </div>
        </>
      ) : (
        <p className="text-base text-fg-muted">{alreadySignedOut}</p>
      )}

      <p className="text-base">
        {/* A document visit: the destination is another surface entry point with its own guards. */}
        <TextLink href={homeLink.href}>{homeLink.label}</TextLink>
      </p>
    </Page>
  );
}
