// The one-time-code step of a base identity registration.
//
// The form posts as a document with the verb the route expects, because the server answers a wrong
// code by re-rendering this page and a correct one with a redirect that may leave this host.
import { Link } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type OtpVerificationProps = {
  title: string;
  description: string;
  delivery_help: string;
  form: {
    action: string;
    scope: string;
    code_label: string;
    code_placeholder: string;
    submit: string;
    turnstile: {
      site_key: string;
      mode: "render" | "execute";
      action: string | null;
      cdata: string | null;
    };
  };
  cancel_link: { label: string; href: string };
  error_messages: string[];
};

export default function OtpVerification({
  title,
  description,
  delivery_help: deliveryHelp,
  form,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: OtpVerificationProps) {
  return (
    <Page
      title={title}
      description={description}
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
          name="_method"
          value="patch"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <ErrorList errors={errorMessages} />

        <TextField
          label={form.code_label}
          name={`${form.scope}[pass_code]`}
          type="text"
          placeholder={form.code_placeholder}
          autoComplete="one-time-code"
          inputMode="numeric"
          pattern="[0-9]*"
          description={deliveryHelp}
        />

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
