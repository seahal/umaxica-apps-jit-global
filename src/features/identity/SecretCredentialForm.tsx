// The create and rename screens of a secret credential.
//
// The secret value field is present only when the server sent its label, which is what separates
// creation from a rename.
import { Link } from "@inertiajs/react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import type { LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type SecretCredentialFormProps = {
  title: string;
  description: string;
  form: {
    action: string;
    scope: string;
    name: string;
    name_label: string;
    value_label?: string;
    confirm_saved_label?: string;
    submit: string;
    /** "patch" on the rename screen; absent for creation, which is a plain POST. */
    method?: string;
  };
  cancel_link: LabelledLink;
  turnstile: TurnstileProps;
  error_header: string | null;
  error_messages: string[];
};

const LINK = "text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline";

export default function SecretCredentialForm({
  title,
  description,
  form,
  cancel_link: cancelLink,
  turnstile,
  error_header: errorHeader,
  error_messages: errorMessages,
}: SecretCredentialFormProps) {
  return (
    <Page
      title={title}
      description={description}
      width="wide"
    >
      <form
        action={form.action}
        method="post"
        data-turbo="false"
        className="flex flex-col gap-4 rounded-lg border border-line bg-surface p-4"
      >
        {form.method ? (
          <input
            type="hidden"
            name="_method"
            value={form.method}
          />
        ) : null}
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <ErrorList
          errors={errorMessages}
          {...(errorHeader === null ? {} : { header: errorHeader })}
        />

        <TextField
          label={form.name_label}
          name={`${form.scope}[name]`}
          defaultValue={form.name}
        />

        {form.value_label ? (
          <TextField
            label={form.value_label}
            name={`${form.scope}[value]`}
          />
        ) : null}

        {form.confirm_saved_label ? (
          <Checkbox
            name="confirm_secret_credential_saved"
            value="1"
          >
            {form.confirm_saved_label}
          </Checkbox>
        ) : null}

        <TurnstileWidget
          site_key={turnstile.site_key}
          mode={turnstile.mode}
          action={turnstile.action}
          cdata={turnstile.cdata}
        />

        <div className="flex items-center justify-end gap-3">
          <Link
            href={cancelLink.href}
            className={LINK}
          >
            {cancelLink.label}
          </Link>
          <Button type="submit">{form.submit}</Button>
        </div>
      </form>
    </Page>
  );
}
