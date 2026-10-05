import { router } from "@inertiajs/react";
import { useId, useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import type {
  IdentityDestructiveAction,
  IdentityLink,
  IdentityPreferenceField,
} from "@/types/identity";

type EmailEditForm = {
  action: string;
  submit_label: string;
  locked: boolean;
  always_on_label: string;
  always_on_description: string;
  promotional: IdentityPreferenceField;
  notifiable: IdentityPreferenceField;
};

type Props = {
  title: string;
  address: string;
  form: EmailEditForm;
  delete: IdentityDestructiveAction;
  cancel_link: IdentityLink;
  error: string | null;
};

export default function EmailEdit({
  title,
  address,
  form,
  delete: destroy,
  cancel_link: cancelLink,
  error,
}: Props) {
  const descriptionId = useId();
  const [promotional, setPromotional] = useState(form.promotional.checked);
  const [notifiable, setNotifiable] = useState(form.notifiable.checked);
  const [processing, setProcessing] = useState(false);
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      {
        user_email: {
          promotional: promotional ? "1" : "0",
          notifiable: notifiable ? "1" : "0",
        },
      },
      {
        onStart: () => setProcessing(true),

        onFinish: () => setProcessing(false),
      },
    );
  };

  const remove = () => {
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => router.delete(destroy.url),
    );
  };

  return (
    <Page
      title={title}
      description={address}
      width="narrow"
    >
      <ErrorList errors={error === null ? [] : [error]} />

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-5"
        >
          <div className="flex flex-col gap-1">
            <span className="text-base font-medium text-fg">{form.always_on_label}</span>
            <p className="text-base text-fg-muted">{form.always_on_description}</p>
          </div>

          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <Checkbox
                id="user_email_promotional"
                aria-describedby={`${descriptionId}-promotional`}
                isDisabled={form.locked}
                isSelected={promotional}
                onChange={setPromotional}
              >
                {form.promotional.label}
              </Checkbox>
              <p
                id={`${descriptionId}-promotional`}
                className="pl-6 text-base text-fg-muted"
              >
                {form.promotional.description}
              </p>
            </div>

            <div className="flex flex-col gap-1">
              <Checkbox
                id="user_email_notifiable"
                aria-describedby={`${descriptionId}-notifiable`}
                isDisabled={form.locked}
                isSelected={notifiable}
                onChange={setNotifiable}
              >
                {form.notifiable.label}
              </Checkbox>
              <p
                id={`${descriptionId}-notifiable`}
                className="pl-6 text-base text-fg-muted"
              >
                {form.notifiable.description}
              </p>
            </div>
          </div>

          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
        </form>
      </Card>

      <Card>
        <Button
          type="button"
          variant="danger"
          onPress={remove}
        >
          {destroy.label}
        </Button>
      </Card>

      <p className="text-base">
        <TextLink
          href={cancelLink.href}
          tone="muted"
          inertia
        >
          {cancelLink.label}
        </TextLink>
      </p>
      {dialog}
    </Page>
  );
}
