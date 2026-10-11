// The secret-credential stage of normal operator sign-in, for a lost passkey.
//
// No identifier field: Entra ID already selected the operator and the server verifies the secret
// against that operator alone, so there is nothing here for a browser to substitute.
//
// A document POST, as the ERB form was: the server answers with a redirect on success and with this
// page re-rendered at 422 on failure, and the visible Turnstile token has to travel in the form
// body under the field name the server verifies.
import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgSecretSignInPageProps = {
  title: string;
  form_action: string;
  hidden_fields: { pt: string | null; ri: string };
  errors_title: string;
  errors: string[];
  secret: { name: string; label: string; placeholder: string };
  submit_label: string;
  back_link: { label: string; href: string };
  turnstile: TurnstileConfiguration;
};

export default function OrgSecretSignInPage({
  title,
  form_action: formAction,
  hidden_fields: hiddenFields,
  errors_title: errorsTitle,
  errors,
  secret,
  submit_label: submitLabel,
  back_link: backLink,
  turnstile,
}: OrgSecretSignInPageProps) {
  return (
    <Page
      title={title}
      up={backLink}
      width="narrow"
    >
      <form
        action={formAction}
        method="post"
        className="flex flex-col gap-4"
      >
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />

        <ErrorList
          errors={errors}
          header={errorsTitle}
        />

        {hiddenFields.pt ? (
          <input
            type="hidden"
            name="pt"
            value={hiddenFields.pt}
            readOnly
          />
        ) : null}
        <input
          type="hidden"
          name="ri"
          value={hiddenFields.ri}
          readOnly
        />

        <TextField
          label={secret.label}
          type="password"
          name={secret.name}
          placeholder={secret.placeholder}
          autoComplete="current-password"
        />

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <Button type="submit">{submitLabel}</Button>
      </form>
    </Page>
  );
}
