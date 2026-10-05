// The one-time code step of the email sign-in ceremony.
//
// The resend control talks to the same JSON endpoint with the same opaque resend state the Stimulus
// controller used, so the cooldown stays a server decision. The code itself is only ever typed here;
// it is never rendered into the page.
import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import OtpResendButton, { type OtpResendMessages } from "@/features/auth/otp/OtpResendButton";
import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

export type SignInEmailEditProps = {
  title: string;
  description: string;
  action: string;
  pt: string | null;
  field_label: string;
  field_placeholder: string;
  submit_label: string;
  delivery_help: string;
  return_link: { label: string; href: string };
  resend: { endpoint: string; state: string; messages: OtpResendMessages };
  turnstile: TurnstileConfiguration;
};

export default function SignInEmailEdit({
  title,
  description,
  action,
  pt,
  field_label: fieldLabel,
  field_placeholder: fieldPlaceholder,
  submit_label: submitLabel,
  delivery_help: deliveryHelp,
  return_link: returnLink,
  resend,
  turnstile,
}: SignInEmailEditProps) {
  const form = useForm({
    user_email: { pass_code: "" },
    pt: pt ?? "",
    "cf-turnstile-response": "",
  });
  const error = readString(form.errors, "pass_code");

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(action);
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
          placeholder={fieldPlaceholder}
          {...(error === undefined ? {} : { errorMessage: error, className: "animate-shake" })}
          name="user_email[pass_code]"
          maxLength={6}
          autoComplete="one-time-code"
          inputMode="numeric"
          pattern="[0-9]*"
          value={form.data.user_email.pass_code}
          onChange={(value) => form.setData("user_email", { pass_code: value })}
          isRequired
        />

        <OtpResendButton
          endpoint={resend.endpoint}
          state={resend.state}
          messages={resend.messages}
          onResent={() => form.setData("user_email", { pass_code: "" })}
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

      <p className="text-base text-fg-muted">{deliveryHelp}</p>

      <p className="text-base">
        <a
          href={returnLink.href}
          className="ui-text-link text-fg underline underline-offset-4 hover:underline"
        >
          <span>{returnLink.label}</span>
        </a>
      </p>
    </Page>
  );
}
