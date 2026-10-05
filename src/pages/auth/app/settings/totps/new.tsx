// Enrolling a new authenticator app.
//
// An enrolment is started once by an explicit POST (`start`); until then the
// page shows only that start. Cancelling is a DELETE that ends the Base permission. The
// form carries the enrolment id so a page from an earlier enrolment cannot confirm the current one.
//
// The provisioning QR code is rendered by the server into a data URI, the same image the ERB screen
// displayed; the QR carries the secret from an encrypted server-side candidate. The first
// code the actor types is verified server-side, and an invisible Turnstile token travels with the
// submission exactly as before.
import { useForm } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";
import type { SettingsLink, SettingsTurnstile } from "@/features/auth/settings/links";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  start: { action: string; label: string } | null;
  qr_code_image: string | null;
  qr_fallback: string;
  form: {
    action: string;
    scope: string;
    title_label: string;
    title_placeholder: string;
    title_hint: string;
    title: string | null;
    enrollment_id: string | null;
    first_token_label: string;
    first_token_placeholder: string;
    first_token_help: string;
    first_token_delivery_help: string;
    submit_label: string;
  };
  cancel: CeremonyCancellationProps | null;
  turnstile: SettingsTurnstile;
  error_header: string | null;
  error_messages: string[];
};

export default function TotpsNew({
  title,
  description,
  back_link: backLink,
  start,
  qr_code_image: qrCodeImage,
  qr_fallback: qrFallback,
  form: formProps,
  cancel,
  turnstile,
  error_header: errorHeader,
  error_messages: errorMessages,
}: Props) {
  const [token, setToken] = useState("");
  const form = useForm({ title: formProps.title ?? "", first_token: "" });

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({
      [formProps.scope]: { ...data, enrollment_id: formProps.enrollment_id },
      "cf-turnstile-response": token,
    }));
    form.post(formProps.action);
  };

  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <ErrorList
        errors={errorMessages}
        {...(errorHeader === null ? {} : { header: errorHeader })}
      />

      {start ? (
        <form
          action={start.action}
          method="post"
          data-turbo="false"
          onSubmit={(event) => {
            const field = event.currentTarget.elements.namedItem("authenticity_token");
            if (field instanceof HTMLInputElement) field.value = csrfToken();
          }}
        >
          <input
            type="hidden"
            name="authenticity_token"
            defaultValue=""
          />
          <Button type="submit">{start.label}</Button>
        </form>
      ) : null}

      {qrCodeImage ? (
        <Card>
          <form
            onSubmit={submit}
            className="flex flex-col gap-5"
          >
            <div className="flex flex-col items-center gap-2">
              <img
                src={qrCodeImage}
                alt="QR Code"
                className="size-48 rounded-lg border border-line bg-white p-2"
              />
              <p className="text-center text-base break-all text-fg-muted">{qrFallback}</p>
            </div>

            <TextField
              id="totp-title"
              label={formProps.title_label}
              type="text"
              maxLength={32}
              placeholder={formProps.title_placeholder}
              description={formProps.title_hint}
              value={form.data.title}
              onChange={(value) => form.setData("title", value)}
            />

            <div className="flex flex-col gap-1">
              <TextField
                id="totp-first-token"
                label={formProps.first_token_label}
                type="text"
                maxLength={6}
                inputMode="numeric"
                placeholder={formProps.first_token_placeholder}
                description={formProps.first_token_help}
                value={form.data.first_token}
                onChange={(value) => form.setData("first_token", value)}
              />
              <p className="text-base text-fg-muted">{formProps.first_token_delivery_help}</p>
            </div>

            <TurnstileWidget
              site_key={turnstile.site_key}
              mode={turnstile.mode}
              action={turnstile.action}
              cdata={turnstile.cdata}
              onToken={setToken}
            />

            <div className="flex flex-wrap items-center gap-4">
              <Button
                type="submit"
                isDisabled={form.processing}
              >
                {formProps.submit_label}
              </Button>
            </div>
          </form>
        </Card>
      ) : null}

      {cancel ? <CeremonyCancellation {...cancel} /> : null}
    </Page>
  );
}
