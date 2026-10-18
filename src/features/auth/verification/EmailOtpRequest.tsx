// Asks the actor to have a one-time code sent to their verified address.
//
// The address itself never crosses: the server knows which one it delivers to, and the screen only
// starts the delivery. The form is a document POST, exactly as the ERB form was.
import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import CeremonyCancellation, {
  type CeremonyCancellationProps,
} from "@/features/auth/CeremonyCancellation";

import type { VerificationFormBase, VerificationLink } from "./types";
import VerificationFormFields from "./VerificationFormFields";

export type EmailOtpRequestProps = {
  title: string;
  heading: string;
  description: string;
  errors: string[];
  form: VerificationFormBase;
  back: VerificationLink;
  cancel: CeremonyCancellationProps;
};

export default function EmailOtpRequest({
  heading,
  description,
  errors,
  form,
  back,
  cancel,
}: EmailOtpRequestProps) {
  return (
    <Page
      title={heading}
      description={description}
      up={back}
      width="narrow"
    >
      <ErrorList errors={errors} />

      <form
        action={form.action}
        method="post"
      >
        <VerificationFormFields
          csrf_token={form.csrf_token}
          scope={form.scope}
          pt={form.pt}
        />
        <Button type="submit">{form.submit_label}</Button>
      </form>
      {/* Back returns to method selection; this ends the whole Step-Up ceremony. */}
      <CeremonyCancellation {...cancel} />
    </Page>
  );
}
