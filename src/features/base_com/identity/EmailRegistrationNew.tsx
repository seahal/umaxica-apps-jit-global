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

// Replaces `app/views/base/com/identity/emails/registrations/new.html.erb`.

export type EmailRegistrationNewProps = {
  title: string;
  back_link: PageLink;
  errors: string[];
  form: { url: string; method: "post"; scope: string; submit_label: string };
  address_label: string;
  address_value: string;
  notifiable: { label: string; description: string; checked: boolean };
  cancel_link: PageLink;
  turnstile: TurnstileProps;
};

export default function EmailRegistrationNew({
  title,
  back_link: backLink,
  errors,
  form,
  address_label: addressLabel,
  address_value: addressValue,
  notifiable,
  cancel_link: cancelLink,
  turnstile,
}: EmailRegistrationNewProps) {
  const [address, setAddress] = useState(addressValue);
  const [notifiableChecked, setNotifiableChecked] = useState(notifiable.checked);
  const [token, setToken] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        [form.scope]: { address, notifiable: notifiableChecked ? "1" : "0" },
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
      up={backLink}
      upVisit="inertia"
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ErrorList errors={errors} />

        <TextField
          id={`${form.scope}_address`}
          label={addressLabel}
          name={`${form.scope}[address]`}
          type="email"
          autoComplete="email"
          isRequired
          value={address}
          onChange={setAddress}
        />

        <div className="flex flex-col gap-1">
          <Checkbox
            id={`${form.scope}_notifiable`}
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

        <div className="flex flex-wrap items-center gap-4">
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
          <TextLink
            href={cancelLink.href}
            inertia
            tone="muted"
          >
            {cancelLink.label}
          </TextLink>
        </div>
      </form>
    </Page>
  );
}
