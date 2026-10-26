import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import { csrfToken } from "@/lib/csrf";

// The sign-out confirmation ceremony, shared by the auth surfaces.
//
// Sign-out is destructive, so both the confirmation and the cancellation keep the HTTP verbs the
// Rails routes expect (POST and DELETE). Nothing here is a link.
//
// Both forms are full document submissions, not Inertia visits: the confirmation answers with a 303
// to the jump gateway on another origin, which an Inertia `fetch` would follow transparently and
// then reject as a non-Inertia response.
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
  };
  cancel: {
    label: string;
    action: string;
  } | null;
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
              data-turbo="false"
            >
              <input
                type="hidden"
                name="authenticity_token"
                value={csrfToken()}
              />
              <Button
                type="submit"
                variant="danger"
              >
                {submitLabel}
              </Button>
            </form>
            {cancel ? (
              <form
                action={cancel.action}
                method="post"
                data-turbo="false"
              >
                <input
                  type="hidden"
                  name="authenticity_token"
                  value={csrfToken()}
                />
                <input
                  type="hidden"
                  name="_method"
                  value="delete"
                />
                <Button
                  type="submit"
                  variant="secondary"
                >
                  {cancel.label}
                </Button>
              </form>
            ) : null}
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
