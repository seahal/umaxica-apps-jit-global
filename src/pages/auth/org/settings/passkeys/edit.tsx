// Renaming a registered passkey.
//
// The form is a document PATCH so the stealth Turnstile token travels in the same field the server
// verifies; the server answers a rejected update by re-rendering this page with 422 and the model's
// error messages, exactly as the ERB form did.
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgPasskeySettingsEditProps = {
  title: string;
  form_action: string;
  description_label: string;
  description_value: string;
  submit_label: string;
  cancel_link: { label: string; href: string };
  errors_title: string;
  errors: string[];
  turnstile: TurnstileConfiguration;
};

export default function OrgPasskeySettingsEdit({
  title,
  form_action: formAction,
  description_label: descriptionLabel,
  description_value: descriptionValue,
  submit_label: submitLabel,
  cancel_link: cancelLink,
  errors_title: errorsTitle,
  errors,
  turnstile,
}: OrgPasskeySettingsEditProps) {
  return (
    <Page
      title={title}
      width="narrow"
    >
      <Card>
        <form
          action={formAction}
          method="post"
          className="flex flex-col gap-4"
        >
          <input
            type="hidden"
            name="_method"
            value="patch"
            readOnly
          />
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

          <TextField
            label={descriptionLabel}
            type="text"
            name="staff_passkey[description]"
            defaultValue={descriptionValue}
            maxLength={100}
          />

          <TurnstileWidget
            site_key={turnstile.site_key}
            mode={turnstile.mode}
            action={turnstile.action}
            cdata={turnstile.cdata}
          />

          <Button type="submit">{submitLabel}</Button>
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
