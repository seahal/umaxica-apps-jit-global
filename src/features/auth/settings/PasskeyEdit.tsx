// Renames one registered passkey.
//
// Validation failures come back as an Inertia redirect carrying the errors hash, so the field reads
// its message from `errors` rather than from a re-rendered 422 body.
import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { TurnstileConfiguration } from "@/features/auth/settings/PasskeyDeleteButton";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

export type PasskeyEditProps = {
  title: string;
  action: string;
  field_label: string;
  description: string;
  submit_label: string;
  cancel_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function PasskeyEdit({
  title,
  action,
  field_label: fieldLabel,
  description,
  submit_label: submitLabel,
  cancel_link: cancelLink,
  turnstile,
}: PasskeyEditProps) {
  // The parameter stays wrapped in `visitor_passkey`, which is the scope the controller permits.
  const form = useForm({
    visitor_passkey: { description: description },
    "cf-turnstile-response": "",
  });
  const error = readString(form.errors, "description");

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(action);
  };

  return (
    <Page
      title={title}
      width="narrow"
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <TextField
          label={fieldLabel}
          name="visitor_passkey[description]"
          maxLength={100}
          value={form.data.visitor_passkey.description}
          onChange={(value) => form.setData("visitor_passkey", { description: value })}
          /* v8 ignore next -- the error hash is empty unless the server rejected the rename */
          {...(error === undefined ? {} : { errorMessage: error })}
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => form.setData("cf-turnstile-response", token)}
        />

        <div className="flex items-center gap-4">
          <Button
            type="submit"
            isDisabled={form.processing}
          >
            {submitLabel}
          </Button>
          <TextLink
            href={cancelLink.href}
            tone="muted"
            className="text-base"
          >
            {cancelLink.label}
          </TextLink>
        </div>
      </form>
    </Page>
  );
}
