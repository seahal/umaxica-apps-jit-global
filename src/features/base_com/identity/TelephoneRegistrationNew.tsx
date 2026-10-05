import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/telephones/registrations/new.html.erb`.

export type TelephoneRegistrationNewProps = {
  title: string;
  description: string;
  errors: string[];
  form: { url: string; method: "post"; scope: string; submit_label: string };
  number_label: string;
  number_placeholder: string;
  help_text: string;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function TelephoneRegistrationNew({
  title,
  description,
  errors,
  form,
  number_label: numberLabel,
  number_placeholder: numberPlaceholder,
  help_text: helpText,
  cancel_link: cancelLink,
  turnstile,
}: TelephoneRegistrationNewProps) {
  const [rawNumber, setRawNumber] = useState("");
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        [form.scope]: { raw_number: rawNumber },
        "cf-turnstile-response": token,
      },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <Page
      title={title}
      description={description}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4 rounded-lg border border-line bg-surface p-4"
      >
        <ErrorList errors={errors} />

        <TextField
          id={`${form.scope}_raw_number`}
          label={numberLabel}
          name={`${form.scope}[raw_number]`}
          type="tel"
          placeholder={numberPlaceholder}
          description={helpText}
          value={rawNumber}
          onChange={setRawNumber}
        />

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <div className="flex flex-wrap items-center justify-end gap-3">
          <TextLink
            href={cancelLink.href}
            inertia
            tone="muted"
          >
            {cancelLink.label}
          </TextLink>
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
        </div>
      </form>
    </Page>
  );
}
