// The per-address email preference screen.
//
// The always-on notifications are described but not offered as a control, because the server sends
// them unconditionally; only the two preferences the operator may actually change have inputs.
import { Link } from "@inertiajs/react";
import { useId } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import type { ConfirmedAction, LabelledLink, TurnstileProps } from "@/features/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

export type EmailPreferenceEditProps = {
  title: string;
  address: string;
  form: {
    action: string;
    scope: string;
    promotional: boolean;
    notifiable: boolean;
    always_on_label: string;
    always_on_description: string;
    promotional_label: string;
    promotional_description: string;
    notifiable_label: string;
    notifiable_description: string;
    submit: string;
    turnstile: TurnstileProps;
  };
  delete: ConfirmedAction;
  cancel_link: LabelledLink;
  error_messages: string[];
};

export default function EmailPreferenceEdit({
  title,
  address,
  form,
  delete: destroy,
  cancel_link: cancelLink,
  error_messages: errorMessages,
}: EmailPreferenceEditProps) {
  const descriptionId = useId();
  const { confirm, dialog } = useConfirm();

  // The deletion is held back until the actor accepts, then replayed with `submit()`, which sends
  // the same document DELETE without running this handler again.
  const submitDeletion = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const deletionForm = event.currentTarget;
    confirm(
      { message: destroy.confirm, confirmLabel: destroy.label, cancelLabel: cancelLink.label },
      () => deletionForm.submit(),
    );
  };

  return (
    <Page
      title={title}
      description={address}
      width="narrow"
    >
      <form
        action={form.action}
        method="post"
        data-turbo="false"
        className="flex flex-col gap-4"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />

        <ErrorList errors={errorMessages} />

        <div className="flex flex-col gap-1">
          <p className="text-base font-medium text-fg">{form.always_on_label}</p>
          <p className="text-base text-fg-muted">{form.always_on_description}</p>
        </div>

        <div className="flex flex-col gap-1">
          <input
            type="hidden"
            name={`${form.scope}[promotional]`}
            value="0"
          />
          <Checkbox
            aria-describedby={`${descriptionId}-promotional`}
            name={`${form.scope}[promotional]`}
            value="1"
            defaultSelected={form.promotional}
          >
            {form.promotional_label}
          </Checkbox>
          <p
            id={`${descriptionId}-promotional`}
            className="pl-6 text-base text-fg-muted"
          >
            {form.promotional_description}
          </p>
        </div>

        <div className="flex flex-col gap-1">
          <input
            type="hidden"
            name={`${form.scope}[notifiable]`}
            value="0"
          />
          <Checkbox
            aria-describedby={`${descriptionId}-notifiable`}
            name={`${form.scope}[notifiable]`}
            value="1"
            defaultSelected={form.notifiable}
          >
            {form.notifiable_label}
          </Checkbox>
          <p
            id={`${descriptionId}-notifiable`}
            className="pl-6 text-base text-fg-muted"
          >
            {form.notifiable_description}
          </p>
        </div>

        <TurnstileWidget
          site_key={form.turnstile.site_key}
          mode={form.turnstile.mode}
          action={form.turnstile.action}
          cdata={form.turnstile.cdata}
        />

        <Button type="submit">{form.submit}</Button>
      </form>

      <form
        action={destroy.href}
        method="post"
        data-turbo="false"
        onSubmit={submitDeletion}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />
        <Button
          type="submit"
          variant="danger"
        >
          {destroy.label}
        </Button>
      </form>

      <Link
        href={cancelLink.href}
        className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
      >
        {cancelLink.label}
      </Link>
      {dialog}
    </Page>
  );
}
