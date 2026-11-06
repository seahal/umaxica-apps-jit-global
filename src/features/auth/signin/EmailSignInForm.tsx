// Step one of the email sign-in ceremony: submit the address that receives the one-time code.
//
// The endpoint, the verb, the parameter wrapper and the Turnstile challenge are all server
// decisions that arrive as props; the form only collects the address and the token. It never learns
// whether the address is registered - the server answers identically either way.
import { useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

import type { SignInField, SignInLink, SignInTurnstile } from "./types";

export type EmailSignInFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    method: string;
    pt: string | null;
    authenticity_token: string;
    address_field: SignInField;
    submit_label: string;
  };
  turnstile: SignInTurnstile;
  form_errors: string[];
  back_link: SignInLink;
  cancel: CeremonyCancellationProps | null;
};

export default function EmailSignInForm({
  title,
  description,
  form,
  turnstile,
  form_errors: formErrors,
  back_link: backLink,
  cancel,
}: EmailSignInFormProps) {
  const field = form.address_field;
  const [address, setAddress] = useState(field.value ?? "");
  const [isSubmitting, setIsSubmitting] = useState(false);

  return (
    <Page
      title={title}
      up={backLink}
      description={description}
      width="narrow"
    >
      <form
        action={form.action}
        method={form.method}
        data-turbo="false"
        className="flex flex-col gap-4"
        onSubmit={() => setIsSubmitting(true)}
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={form.authenticity_token}
        />
        {form.pt !== null ? (
          <input
            type="hidden"
            name="pt"
            value={form.pt}
          />
        ) : null}
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
          value={address}
          onChange={setAddress}
          placeholder={field.placeholder}
          isRequired
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <Button
          type="submit"
          isDisabled={isSubmitting}
        >
          {form.submit_label}
        </Button>
      </form>

      {cancel ? <CeremonyCancellation {...cancel} /> : null}
    </Page>
  );
}
