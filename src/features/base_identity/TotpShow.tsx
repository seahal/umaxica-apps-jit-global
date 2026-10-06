import { router, useForm } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  totp: { public_id: string; title: string | null; last_otp_at: string; status: string };
  form: { action: string; title: string; label: string; submit_label: string };
  destroy: { action: string; label: string; confirm: string };
  error: string | null;
};

export default function TotpShow({
  title,
  description,
  back_link: backLink,
  totp,
  form: formProps,
  destroy,
  error,
}: Props) {
  const form = useForm({ title: formProps.title });
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({ client_totp_credential: data }));
    form.patch(formProps.action);
  };

  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      {error ? <p className="text-base text-error">{error}</p> : null}
      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-4"
        >
          <TextField
            id="totp-title"
            label={formProps.label}
            maxLength={32}
            value={form.data.title}
            onChange={(value) => form.setData("title", value)}
          />
          <Button
            type="submit"
            isDisabled={form.processing}
          >
            {formProps.submit_label}
          </Button>
        </form>
      </Card>
      <dl className="flex flex-col gap-2 text-base">
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Status</dt>
          <dd>{totp.status}</dd>
        </div>
        <div className="flex flex-wrap gap-2">
          <dt className="font-medium">Last used</dt>
          <dd>{totp.last_otp_at}</dd>
        </div>
      </dl>
      <Card>
        <Button
          type="button"
          variant="danger"
          onPress={() =>
            confirm({ message: destroy.confirm, confirmLabel: destroy.label }, () => router.delete(destroy.action))
          }
        >
          {destroy.label}
        </Button>
      </Card>
      <TextLink href={backLink.href}>{backLink.label}</TextLink>
      {dialog}
    </Page>
  );
}
