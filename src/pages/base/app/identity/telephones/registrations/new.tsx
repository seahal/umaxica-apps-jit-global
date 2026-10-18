import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink } from "@/types/identity";

type Props = {
  title: string;
  description: string;
  help_text: string;
  number_label: string;
  number_placeholder: string;
  form: { action: string; submit_label: string };
  cancel_link: IdentityLink;
  errors: string[];
};

export default function TelephoneRegistrationNew({
  title,
  description,
  help_text: helpText,
  number_label: numberLabel,
  number_placeholder: numberPlaceholder,
  form,
  cancel_link: cancelLink,
  errors,
}: Props) {
  const [rawNumber, setRawNumber] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
      { user_telephone: { raw_number: rawNumber } },
      {
        onStart: () => setProcessing(true),

        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <Page
      title={title}
      description={description}
      width="narrow"
    >
      <ErrorList errors={errors} />

      <Card>
        <form
          onSubmit={submit}
          className="flex flex-col gap-4"
        >
          <TextField
            id="user_telephone_raw_number"
            label={numberLabel}
            type="tel"
            placeholder={numberPlaceholder}
            description={helpText}
            value={rawNumber}
            onChange={setRawNumber}
          />

          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
        </form>
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
    </Page>
  );
}
