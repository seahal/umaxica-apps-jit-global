// Start of the email sign-in ceremony: the address a one-time code is sent to.
//
// The Turnstile token travels with the submission exactly as the ERB form posted it, and the server
// still decides whether the challenge passed. A validation failure comes back as a redirect with the
// errors hash.
import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

export type SignInEmailNewProps = {
  title: string;
  description: string;
  action: string;
  pt: string | null;
  field_label: string;
  submit_label: string;
  back_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function SignInEmailNew({
  title,
  description,
  action,
  pt,
  field_label: fieldLabel,
  submit_label: submitLabel,
  back_link: backLink,
  turnstile,
}: SignInEmailNewProps) {
  const form = useForm({
    user_email: { address: "" },
    pt: pt ?? "",
    "cf-turnstile-response": "",
  });
  const error = readString(form.errors, "address");

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.post(action);
  };

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <TextField
          label={fieldLabel}
          type="email"
          placeholder="name@example.com"
          {...(error === undefined ? {} : { errorMessage: error, className: "animate-shake" })}
          name="user_email[address]"
          value={form.data.user_email.address}
          onChange={(value) => form.setData("user_email", { address: value })}
          isRequired
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => form.setData("cf-turnstile-response", token)}
        />

        <Button
          type="submit"
          isDisabled={form.processing}
        >
          {submitLabel}
        </Button>
      </form>

      <p className="text-base">
        <a
          href={backLink.href}
          className="ui-text-link text-fg underline underline-offset-4 hover:underline"
        >
          <span>{backLink.label}</span>
        </a>
      </p>
    </Page>
  );
}
