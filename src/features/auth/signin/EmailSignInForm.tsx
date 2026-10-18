// Step one of the email sign-in ceremony: submit the address that receives the one-time code.
//
// The endpoint, the verb, the parameter wrapper and the Turnstile challenge are all server
// decisions that arrive as props; the form only collects the address and the token. It never learns
// whether the address is registered - the server answers identically either way.
import { useForm } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { readString } from "@/lib/payload";

import type { SignInField, SignInLink, SignInTurnstile } from "./types";

export type EmailSignInFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    pt: string | null;
    address_field: SignInField;
    submit_label: string;
  };
  turnstile: SignInTurnstile;
  form_errors: string[];
  back_link: SignInLink;
};

export default function EmailSignInForm({
  title,
  description,
  form,
  turnstile,
  form_errors: formErrors,
  back_link: backLink,
}: EmailSignInFormProps) {
  const field = form.address_field;
  const { data, setData, post, processing } = useForm<{
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

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <form
        onSubmit={(event) => {
          event.preventDefault();
          post(form.action);
        }}
        className="flex flex-col gap-4"
      >
        {formErrors.length > 0 ? (
          <div
            className="animate-shake rounded-md border border-danger bg-surface p-3"
            role="alert"
          >
            <ul className="flex flex-col gap-1 text-base text-error">
              {formErrors.map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          </div>
        ) : null}

        <TextField
          label={field.label}
          type="email"
          name={field.name}
          value={value}
          onChange={(next) => setData(field.scope, { [field.field]: next })}
          placeholder={field.placeholder}
          isRequired
        />

        <TurnstileWidget
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

      <p className="text-base">
        {/* Document visit: leaving the ceremony returns to the method selection page. */}
        <a
          href={backLink.href}
          className="ui-text-link text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
        >
          {backLink.label}
        </a>
      </p>
    </Page>
  );
}
