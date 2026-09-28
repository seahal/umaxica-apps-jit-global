// Enters the one-time code delivered by email.
//
// The code is never a prop: it exists only in the message the server sent and in what the actor
// types here. The form is a document PATCH (POST plus Rails' `_method`), exactly as the ERB form
// was, so the server can answer it with the step-up completion hand-off document.
import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

import type { VerificationFormBase, VerificationLink } from "./types";
import VerificationFormFields from "./VerificationFormFields";

export type EmailOtpEntryForm = VerificationFormBase & {
  code_label: string;
  code_placeholder: string;
};

export type EmailOtpEntryResend = {
  action: string;
  csrf_token: string;
  label: string;
};

export type EmailOtpEntryProps = {
  title: string;
  heading: string;
  description: string;
  delivery_help: string;
  errors: string[];
  form: EmailOtpEntryForm;
  resend: EmailOtpEntryResend;
  back: VerificationLink;
  cancel: CeremonyCancellationProps;
};

export default function EmailOtpEntry({
  heading,
  description,
  delivery_help: deliveryHelp,
  errors,
  form,
  resend,
  back,
  cancel,
}: EmailOtpEntryProps) {
  return (
    <Page
      title={heading}
      description={description}
      up={back}
      width="narrow"
    >
      <p className="text-sm text-fg-muted">{deliveryHelp}</p>

      <ErrorList errors={errors} />

      <form
        action={form.action}
        method="post"
        className="flex flex-col gap-4"
      >
        <VerificationFormFields
          csrf_token={form.csrf_token}
          scope={form.scope}
          pt={form.pt}
          method="patch"
        />
        <TextField
          label={form.code_label}
          name="verification[code]"
          inputMode="numeric"
          autoComplete="one-time-code"
          placeholder={form.code_placeholder}
        />

        <Button type="submit">{form.submit_label}</Button>
      </form>

      <form
        action={resend.action}
        method="post"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={resend.csrf_token}
          readOnly
        />
        <Button
          type="submit"
          variant="secondary"
        >
          {resend.label}
        </Button>
      </form>
      {/* Back returns to method selection; this ends the whole Step-Up ceremony. */}
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
