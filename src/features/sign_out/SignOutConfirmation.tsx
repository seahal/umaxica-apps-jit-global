// The sign-out confirmation screen, replacing `app/views/base/shared/sign_outs/edit.html.erb`.
//
// Whether a session is still active is a server decision: `form` is absent when there is nothing
// left to sign out of, so the button cannot be offered by the client on its own.
import { Link } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import { csrfToken } from "@/lib/csrf";

export type SignOutConfirmationForm = {
  action: string;
  submit: string;
  logout_challenge: string | null;
  confirm_description: string;
};

export type SignOutConfirmationProps = {
  title: string;
  active: boolean;
  description: string;
  form: SignOutConfirmationForm | null;
} & (
  | { back_link: { label: string; href: string }; home_link?: never }
  | { home_link: { label: string; href: string }; back_link?: never }
);

export default function SignOutConfirmation(props: SignOutConfirmationProps) {
  const { title, description, form } = props;
  if (props.back_link !== undefined && props.home_link !== undefined) {
    throw new Error("A sign-out page must provide one return link");
  }

  const returnLink = props.back_link ?? props.home_link;

  if (!returnLink) {
    throw new Error("A sign-out return link is required");
  }

  return (
    <section className="flex flex-col gap-4">
      <h1 className="text-2xl font-bold text-fg">{title}</h1>
      <p className="text-sm text-fg-muted">{description}</p>

      {form ? (
        // A full document POST, as the ERB form was: sign-out ends the session the Inertia app
        // runs in, so the response is a navigation rather than a page swap.
        <form
          action={form.action}
          method="post"
          data-turbo="false"
          className="flex flex-col gap-3"
        >
          <input
            type="hidden"
            name="authenticity_token"
            value={csrfToken()}
          />
          {form.logout_challenge ? (
            <input
              type="hidden"
              name="logout_challenge"
              value={form.logout_challenge}
              readOnly
            />
          ) : null}
          <div>
            <Button
              type="submit"
              variant="danger"
            >
              {form.submit}
            </Button>
          </div>
          <noscript>
            <p className="text-sm text-fg-muted">{form.confirm_description}</p>
          </noscript>
        </form>
      ) : null}

      <p>
        <Link
          href={returnLink.href}
          className="inline-flex items-center justify-center gap-2 rounded-md border border-line
            bg-surface px-4 py-2 text-sm font-medium text-fg transition-colors
            hover:bg-surface-muted"
        >
          {returnLink.label}
        </Link>
      </p>
    </section>
  );
}
