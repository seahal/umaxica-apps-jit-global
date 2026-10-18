// The number step of adding a telephone identifier.
//
// `turnstile` is absent on the route that does not run the challenge, so the widget is rendered
// only when the server sent its configuration.
import { Link } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type TelephoneRegistrationNewProps = {
  title: string;
  form: {
    action: string;
    scope: string;
    number_label: string;
    number_placeholder: string;
    submit: string;
    turnstile?: TurnstileProps;
  };
  cancel_link: LabelledLink;
  error_messages: string[];
};

const LINK = "text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline";

export default function TelephoneRegistrationNew({
  title,
  form,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: TelephoneRegistrationNewProps) {
  return (
    <Page
      title={title}
      width="wide"
    >
      <form
        action={form.action}
        method="post"
        data-turbo="false"
        className="flex flex-col gap-4 rounded-lg border border-line bg-surface p-4"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <ErrorList errors={errorMessages} />

        <TextField
          label={form.number_label}
          name={`${form.scope}[raw_number]`}
          type="tel"
          placeholder={form.number_placeholder}
        />

        {form.turnstile ? (
          <TurnstileWidget
            site_key={form.turnstile.site_key}
            mode={form.turnstile.mode}
            action={form.turnstile.action}
            cdata={form.turnstile.cdata}
          />
        ) : null}

        <div className="flex items-center justify-end gap-3">
          <Link
            href={cancelLink.href}
            className={LINK}
          >
            {cancelLink.label}
          </Link>
          <Button type="submit">{form.submit}</Button>
        </div>
      </form>
    </Page>
  );
}
