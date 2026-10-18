import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// The delivered-code step of the email and telephone registration ceremonies. Both ERB templates
// submitted the same shape: a one-time code, an optional verification token, and a challenge.

export type OtpCodeFormProps = {
  title: string;
  description: string;
  errors: string[];
  form: { url: string; method: "patch"; scope: string; submit_label: string };
  verification_token?: string | null;
  code_label: string;
  code_placeholder: string;
  delivery_help: string;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function OtpCodeForm({
  title,
  description,
  errors,
  form,
  verification_token: verificationToken,
  code_label: codeLabel,
  code_placeholder: codePlaceholder,
  delivery_help: deliveryHelp,
  cancel_link: cancelLink,
  turnstile,
}: OtpCodeFormProps) {
  const [passCode, setPassCode] = useState("");
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.url,
      {
        [form.scope]: {
          pass_code: passCode,
          ...(verificationToken ? { token: verificationToken } : {}),
        },
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
      width="narrow"
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ErrorList errors={errors} />

        {verificationToken ? (
          <input
            type="hidden"
            name={`${form.scope}[token]`}
            value={verificationToken}
            readOnly
          />
        ) : null}

        <TextField
          id={`${form.scope}_pass_code`}
          label={codeLabel}
          name={`${form.scope}[pass_code]`}
          type="text"
          placeholder={codePlaceholder}
          autoComplete="one-time-code"
          inputMode="numeric"
          pattern="[0-9]*"
          description={deliveryHelp}
          value={passCode}
          onChange={setPassCode}
        />

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <Button
          type="submit"
          isDisabled={processing}
          className="w-fit"
        >
          {form.submit_label}
        </Button>
      </form>

      <TextLink
        href={cancelLink.href}
        inertia
        tone="muted"
      >
        {cancelLink.label}
      </TextLink>
    </Page>
  );
}
