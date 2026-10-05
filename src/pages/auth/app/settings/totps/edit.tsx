// Renames or removes one registered authenticator app.
//
// Removal keeps its confirmation and its DELETE verb; whether it is allowed at all is decided by
// the server, which refuses to leave an account without a way in.
import { router, useForm } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { SettingsLink } from "@/features/auth/settings/links";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  form: {
    action: string;
    scope: string;
    title_label: string;
    title_placeholder: string;
    title_hint: string;
    title: string | null;
    submit_label: string;
  };
  cancel_link: SettingsLink;
  destroy: { action: string; submit_label: string; confirm_message: string };
  error_header: string | null;
  error_messages: string[];
};

export default function TotpsEdit({
  title,
  description,
  back_link: backLink,
  form: formProps,
  cancel_link: cancelLink,
  destroy,
  error_header: errorHeader,
  error_messages: errorMessages,
}: Props) {
  const form = useForm({ title: formProps.title ?? "" });
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({ [formProps.scope]: data }));
    form.patch(formProps.action);
  };

  const remove = () => {
    confirm(
      {
        message: destroy.confirm_message,
        confirmLabel: destroy.submit_label,
        cancelLabel: cancelLink.label,
      },
      () => router.delete(destroy.action),
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
            id="totp-title"
            label={formProps.title_label}
            type="text"
            maxLength={32}
            placeholder={formProps.title_placeholder}
            description={formProps.title_hint}
            value={form.data.title}
            onChange={(value) => form.setData("title", value)}
          />

          <div className="flex flex-wrap items-center gap-4">
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

      {/* Removal is a different decision from renaming, so it sits outside the form's panel. */}
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
