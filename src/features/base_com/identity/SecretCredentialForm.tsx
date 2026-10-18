import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Backs both `new` and `edit` for the base/com secret credential pages: the two ERB templates
// differed only in the one-time secret the create page reveals and in the verb the form uses.

export type SecretCredentialFormProps = {
  title: string;
  description: string;
  errors: { header: string; messages: string[] } | null;
  form: { url: string; method: "post" | "patch"; scope: string; submit_label: string };
  name_label: string;
  name_value: string;
  enabled_label: string;
  enabled: boolean;
  /** Present on the create screen only: the secret is shown once and never fetched again. */
  secret?: { label: string; value: string; one_time_notice: string };
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function SecretCredentialForm({
  title,
  description,
  errors,
  form,
  name_label: nameLabel,
  name_value: nameValue,
  enabled_label: enabledLabel,
  enabled: enabledInitial,
  secret,
  cancel_link: cancelLink,
  turnstile,
}: SecretCredentialFormProps) {
  const [name, setName] = useState(nameValue);
  const [enabled, setEnabled] = useState(enabledInitial);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const nameId = `${form.scope}_name`;
  const enabledId = `${form.scope}_enabled`;

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const payload = {
      [form.scope]: { name, enabled: enabled ? "1" : "0" },
      "cf-turnstile-response": token,
    };
    const options = {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    };

    if (form.method === "patch") {
      router.patch(form.url, payload, options);
    } else {
      router.post(form.url, payload, options);
    }
  };

  return (
    <Page
      title={title}
      description={description}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4 rounded-lg border border-line bg-surface p-4"
      >
        <ErrorList
          errors={errors?.messages ?? []}
          header={errors?.header}
        />

        <TextField
          id={nameId}
          label={nameLabel}
          name={`${form.scope}[name]`}
          value={name}
          onChange={setName}
        />

        <Checkbox
          id={enabledId}
          isSelected={enabled}
          onChange={setEnabled}
        >
          {enabledLabel}
        </Checkbox>

        {secret ? (
          <div className="flex flex-col gap-1 rounded-md border border-line bg-surface-muted p-3">
            <p className="text-base font-medium text-fg">{secret.label}</p>
            <p className="wrap-anywhere font-mono text-base text-fg">{secret.value}</p>
            <p className="text-base font-medium text-fg">{secret.one_time_notice}</p>
          </div>
        ) : null}

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <div className="flex flex-wrap items-center justify-end gap-3">
          <TextLink
            href={cancelLink.href}
            inertia
            tone="muted"
          >
            {cancelLink.label}
          </TextLink>
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
        </div>
      </form>
    </Page>
  );
}
