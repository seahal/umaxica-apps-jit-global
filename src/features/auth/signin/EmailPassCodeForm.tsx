// Step two of the email sign-in ceremony: enter the one-time code that was delivered.
//
// The code itself never reaches this page - only the field that collects it. Whether the code is
// correct, how many attempts remain, and whether the account is locked are all decided by the
// server, which re-renders this page with the resulting messages.
import { useForm } from "@inertiajs/react";
import { useRef, useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

import OtpResendButton, { type OtpResend } from "./OtpResendButton";
import type { SignInLink, SignInTurnstile } from "./types";

export type EmailPassCodeField = {
  scope: string;
  field: string;
  name: string;
  label: string;
  placeholder: string;
  max_length: number;
  autocomplete: string;
  inputmode: "numeric";
  pattern: string;
};

export type EmailPassCodeFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    pt: string | null;
    pass_code_field: EmailPassCodeField;
    submit_label: string;
  };
  otp_resend: OtpResend;
  turnstile: SignInTurnstile;
  form_errors: string[];
  delivery_help: string;
  back_link: SignInLink;
};

export default function EmailPassCodeForm({
  title,
  description,
  form,
  otp_resend: otpResend,
  turnstile,
  form_errors: formErrors,
  delivery_help: deliveryHelp,
  back_link: backLink,
}: EmailPassCodeFormProps) {
  const field = form.pass_code_field;
  const input = useRef<HTMLInputElement>(null);
  const [turnstileKey, setTurnstileKey] = useState(0);
  const { data, setData, patch, processing } = useForm<{
    [key: string]: string | null | Record<string, string>;
    "cf-turnstile-response": string;
    pt: string | null;
  }>({
    [field.scope]: { [field.field]: "" },
    "cf-turnstile-response": "",
    pt: form.pt,
  });

  /* v8 ignore next -- useForm always initialises the scoped field as a string */
  const value = readString(data[field.scope], field.field) ?? "";
  const fieldId = `${field.scope}_${field.field}`;

  const clearSubmissionState = () => {
    setData(field.scope, { [field.field]: "" });
    setData("cf-turnstile-response", "");
    setTurnstileKey((key) => key + 1);
  };

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <form
        onSubmit={(event) => {
          event.preventDefault();
          patch(form.action, { onFinish: clearSubmissionState });
        }}
        className="flex flex-col gap-4"
      >
        {formErrors.length > 0 ? (
          <div
            className="animate-shake rounded-md border border-danger bg-surface p-3"
            role="alert"
          >
            <ul className="flex flex-col gap-1 text-sm text-danger">
              {formErrors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        {/*
          A hand-styled input rather than the shared `TextField`: `TextField` does not forward a
          ref to its underlying control, and `OtpResendButton` needs a real DOM node to refocus
          after a resend clears the field.
        */}
        <div className="flex flex-col gap-1">
          <label
            htmlFor={fieldId}
            className="text-sm font-medium text-fg"
          >
            {field.label}
          </label>
          <input
            ref={input}
            type="text"
            id={fieldId}
            name={field.name}
            value={value}
            onChange={(event) => setData(field.scope, { [field.field]: event.target.value })}
            placeholder={field.placeholder}
            maxLength={field.max_length}
            autoComplete={field.autocomplete}
            inputMode={field.inputmode}
            pattern={field.pattern}
            required
            className="w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg
              placeholder:text-fg-muted"
          />
        </div>

        <OtpResendButton
          resend={otpResend}
          onResent={() => {
            clearSubmissionState();
            input.current?.focus();
          }}
        />

        <TurnstileWidget
          key={turnstileKey}
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
          onToken={(token) => setData("cf-turnstile-response", token)}
        />

        <Button
          type="submit"
          isDisabled={processing}
        >
          {form.submit_label}
        </Button>
      </form>

      <p className="text-sm text-fg-muted">{deliveryHelp}</p>

      <p className="text-sm">
        {/* Document visit: restarting the ceremony issues a new code. */}
        <a
          href={backLink.href}
          className="text-fg-muted underline-offset-4 hover:text-fg hover:underline"
        >
          {backLink.label}
        </a>
      </p>
    </Page>
  );
}
