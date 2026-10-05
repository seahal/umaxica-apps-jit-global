import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import type { IdentityLink } from "@/types/identity";

type VerificationForm = {
  action: string;
  code_label: string;
  code_placeholder: string;
  delivery_help: string;
  submit_label: string;
  turnstile: TurnstileProps;
  verification_token: string | null;
};

type Props = {
  title: string;
  description: string;
  cancel_link: IdentityLink;
  form: VerificationForm;
  resend: { label: string; url: string };
  errors: string[];
};

export default function EmailRegistrationEdit({
  title,
  description,
  cancel_link: cancelLink,
  form,
  resend,
  errors,
}: Props) {
  const [passCode, setPassCode] = useState("");
  const [turnstileToken, setTurnstileToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      {
        user_email: {
          pass_code: passCode,
          ...(form.verification_token ? { token: form.verification_token } : {}),
        },
        "cf-turnstile-response": turnstileToken,
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
      <ErrorList errors={errors} />

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-4"
        >
          <TextField
            id="user_email_pass_code"
            label={form.code_label}
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            autoComplete="one-time-code"
            placeholder={form.code_placeholder}
            description={form.delivery_help}
            value={passCode}
            onChange={setPassCode}
          />

          <TurnstileWidget
            site_key={form.turnstile.site_key}
            mode={form.turnstile.mode}
            action={form.turnstile.action}
            cdata={form.turnstile.cdata}
            onToken={setTurnstileToken}
          />

          <div className="flex flex-wrap items-center gap-3">
            <Button
              type="submit"
              isDisabled={processing}
            >
              {form.submit_label}
            </Button>

            <Button
              type="button"
              variant="secondary"
              onPress={() => router.post(resend.url)}
            >
              {resend.label}
            </Button>
          </div>
        </form>
      </Card>

      <p className="text-base">
        <TextLink
          href={cancelLink.href}
          tone="muted"
        >
          {cancelLink.label}
        </TextLink>
      </p>
    </Page>
  );
}
