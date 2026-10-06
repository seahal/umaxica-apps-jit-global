import { router, useForm } from "@inertiajs/react";
import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import TextField from "@/components/ui/TextField";

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  passkey: { public_id: string; description: string; created_at: string | null; last_used_at: string | null };
  form: { action: string; description: string; label: string; submit_label: string };
  destroy: { action: string; label: string; confirm: string };
  error: string | null;
};

export default function PasskeyShow({
  title,
  description,
  back_link: backLink,
  passkey,
  form: formProps,
  destroy,
  error,
}: Props) {
  const form = useForm({ description: formProps.description });
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.transform((data) => ({ passkey: data }));
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
            label={formProps.label}
            value={form.data.description}
            onChange={(value) => form.setData("description", value)}
          />
          <Button
            type="submit"
            isDisabled={form.processing}
          >
            {formProps.submit_label}
          </Button>
        </form>
      </Card>
      <p>Created: {passkey.created_at ?? "-"}</p>
      <p>Last used: {passkey.last_used_at ?? "-"}</p>
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
