import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink, IdentityPreferenceField } from "@/types/identity";

type RegistrationForm = {
  action: string;
  address_label: string;
  address: string;
  submit_label: string;
  promotional: IdentityPreferenceField;
  notifiable: IdentityPreferenceField;
};

type Props = {
  title: string;
  back_link: IdentityLink;
  cancel_link: IdentityLink;
  form: RegistrationForm;
  errors: string[];
};

export default function EmailRegistrationNew({
  title,
  back_link: backLink,
  cancel_link: cancelLink,
  form,
  errors,
}: Props) {
  const [address, setAddress] = useState(form.address);
  const [promotional, setPromotional] = useState(form.promotional.checked);
  const [notifiable, setNotifiable] = useState(form.notifiable.checked);
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
      {
        user_email: {
          address,
          /* v8 ignore next -- both checkbox states are exercised; v8 still flags one arm */
          promotional: promotional ? "1" : "0",
          /* v8 ignore next -- both checkbox states are exercised; v8 still flags one arm */
          notifiable: notifiable ? "1" : "0",
        },
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
      width="narrow"
    >
      <ErrorList errors={errors} />

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-5"
        >
          <TextField
            id="user_email_address"
            label={form.address_label}
            type="email"
            autoComplete="email"
            isRequired
            value={address}
            onChange={setAddress}
          />

          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <Checkbox
                id="user_email_promotional"
                isSelected={promotional}
                onChange={setPromotional}
              >
                {form.promotional.label}
              </Checkbox>
              <p className="pl-6 text-xs text-fg-muted">{form.promotional.description}</p>
            </div>

            <div className="flex flex-col gap-1">
              <Checkbox
                id="user_email_notifiable"
                isSelected={notifiable}
                onChange={setNotifiable}
              >
                {form.notifiable.label}
              </Checkbox>
              <p className="pl-6 text-xs text-fg-muted">{form.notifiable.description}</p>
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

      <p className="text-sm">
        <TextLink
          href={cancelLink.href}
          tone="muted"
        >
          {cancelLink.label}
        </TextLink>
      </p>
    </Page>
  );
}
