import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import DestructiveButton from "@/features/base_com/identity/DestructiveButton";
import type { ConfirmedAction, PageLink, TurnstileProps } from "@/features/base_com/identity/types";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

// Replaces `app/views/base/com/identity/emails/edit.html.erb`.

type Toggle = { label: string; description: string; checked: boolean };

export type EmailEditProps = {
  title: string;
  address: string;
  errors: string[];
  always_on: { label: string; description: string };
  promotional: Toggle;
  notifiable: Toggle;
  form: { url: string; scope: string; submit_label: string };
  destroy: ConfirmedAction;
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function EmailEdit({
  title,
  address,
  errors,
  always_on: alwaysOn,
  promotional,
  notifiable,
  form,
  destroy,
  cancel_link: cancelLink,
  turnstile,
}: EmailEditProps) {
  const [promotionalChecked, setPromotionalChecked] = useState(promotional.checked);
  const [notifiableChecked, setNotifiableChecked] = useState(notifiable.checked);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.url,
      {
        [form.scope]: {
          promotional: promotionalChecked ? "1" : "0",
          notifiable: notifiableChecked ? "1" : "0",
        },
        "cf-turnstile-response": token,
      },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <Page
      title={title}
      description={address}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ErrorList errors={errors} />

        <div className="rounded-md border border-line bg-surface-muted p-3">
          <p className="text-base font-medium text-fg">{alwaysOn.label}</p>
          <p className="text-sm text-fg-muted">{alwaysOn.description}</p>
        </div>

        <div className="flex flex-col gap-1">
          <Checkbox
            id={`${form.scope}_promotional`}
            name={`${form.scope}[promotional]`}
            aria-describedby={`${form.scope}_promotional_description`}
            isSelected={promotionalChecked}
            onChange={setPromotionalChecked}
          >
            {promotional.label}
          </Checkbox>
          <p
            id={`${form.scope}_promotional_description`}
            className="pl-6 text-sm text-fg-muted"
          >
            {promotional.description}
          </p>
        </div>

        <div className="flex flex-col gap-1">
          <Checkbox
            id={`${form.scope}_notifiable`}
            name={`${form.scope}[notifiable]`}
            aria-describedby={`${form.scope}_notifiable_description`}
            isSelected={notifiableChecked}
            onChange={setNotifiableChecked}
          >
            {notifiable.label}
          </Checkbox>
          <p
            id={`${form.scope}_notifiable_description`}
            className="pl-6 text-sm text-fg-muted"
          >
            {notifiable.description}
          </p>
        </div>

        <TurnstileWidget
          {...turnstile}
          onToken={setToken}
        />

        <Button
          type="submit"
          isDisabled={processing}
          className="w-fit"
        >
          {form.submit_label}
        </Button>
      </form>

      <div className="flex flex-wrap items-center gap-4 border-t border-line pt-4">
        <DestructiveButton action={destroy} />
        <TextLink
          href={cancelLink.href}
          inertia
          tone="muted"
        >
          {cancelLink.label}
        </TextLink>
      </div>
    </Page>
  );
}
