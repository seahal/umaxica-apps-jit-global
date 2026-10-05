// The address step of adding an email identifier.
import { Link } from "@inertiajs/react";
import { useId } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type EmailRegistrationNewProps = {
  title: string;
  form: {
    action: string;
    scope: string;
    address_label: string;
    notifiable: boolean;
    notifiable_label: string;
    notifiable_description: string;
    submit: string;
    turnstile: TurnstileProps;
  };
  cancel_link: LabelledLink;
  error_messages: string[];
};

export default function EmailRegistrationNew({
  title,
  form,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: EmailRegistrationNewProps) {
  const descriptionId = useId();
  return (
    <Page
      title={title}
      width="narrow"
    >
      <form
        action={form.action}
        method="post"
        data-turbo="false"
        className="flex flex-col gap-4"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <ErrorList errors={errorMessages} />

        <TextField
          label={form.address_label}
          type="email"
          name={`${form.scope}[address]`}
          autoComplete="email"
          isRequired
        />

        <div className="flex flex-col gap-1">
          <input
            type="hidden"
            name={`${form.scope}[notifiable]`}
            value="0"
          />
          <Checkbox
            aria-describedby={`${descriptionId}-notifiable`}
            name={`${form.scope}[notifiable]`}
            value="1"
            defaultSelected={form.notifiable}
          >
            {form.notifiable_label}
          </Checkbox>
          <p
            id={`${descriptionId}-notifiable`}
            className="pl-6 text-base text-fg-muted"
          >
            {form.notifiable_description}
          </p>
        </div>

        <TurnstileWidget
          site_key={form.turnstile.site_key}
          mode={form.turnstile.mode}
          action={form.turnstile.action}
          cdata={form.turnstile.cdata}
        />

        <Button type="submit">{form.submit}</Button>
      </form>

      <Link
        href={cancelLink.href}
        className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
      >
        {cancelLink.label}
      </Link>
    </Page>
  );
}
