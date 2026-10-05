// Renames or removes one registered passkey.
//
// Both submissions keep the verb the route expects and carry an invisible Turnstile token, as the
// ERB forms did. Validation failures come back as a re-rendered page carrying the messages the
// model produced.
import { router, useForm } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { SettingsLink, SettingsTurnstile } from "@/features/auth/settings/links";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  form: {
    action: string;
    scope: string;
    description_label: string;
    description: string | null;
    submit_label: string;
  };
  cancel_link: SettingsLink;
  destroy: { action: string; submit_label: string; confirm_message: string };
  turnstile: SettingsTurnstile;
  error_header: string | null;
  error_messages: string[];
};

export default function PasskeysEdit({
  title,
  description,
  back_link: backLink,
  form: formProps,
  cancel_link: cancelLink,
  destroy,
  turnstile,
  error_header: errorHeader,
  error_messages: errorMessages,
}: Props) {
  const [token, setToken] = useState("");
  const form = useForm({ description: formProps.description ?? "" });
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({
      [formProps.scope]: data,
      "cf-turnstile-response": token,
    }));
    form.patch(formProps.action);
  };

  const remove = () => {
    confirm(
      {
        message: destroy.confirm_message,
        confirmLabel: destroy.submit_label,
        cancelLabel: cancelLink.label,
      },
      () => {
        router.delete(destroy.action, { data: { "cf-turnstile-response": token } });
      },
    );
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

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-4"
        >
          <TextField
            id="passkey-description"
            label={formProps.description_label}
            type="text"
            maxLength={100}
            value={form.data.description}
            onChange={(value) => form.setData("description", value)}
          />

          <TurnstileWidget
            site_key={turnstile.site_key}
            mode={turnstile.mode}
            action={turnstile.action}
            cdata={turnstile.cdata}
            onToken={setToken}
          />

          <div className="flex flex-wrap items-center gap-3">
            <Button
              type="submit"
              isDisabled={form.processing}
            >
              {formProps.submit_label}
            </Button>

            <TextLink
              href={cancelLink.href}
              tone="muted"
              className="text-base"
            >
              {cancelLink.label}
            </TextLink>
          </div>
        </form>
      </Card>

      {/*
        Removal is separated from the rename form: they are two different decisions, and the
        destructive one should not sit inside the panel the visitor is editing in.
      */}
      <Card>
        <Button
          type="button"
          variant="danger"
          onPress={remove}
        >
          {destroy.submit_label}
        </Button>
      </Card>
      {dialog}
    </Page>
  );
}
