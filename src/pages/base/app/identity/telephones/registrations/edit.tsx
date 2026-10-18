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
  code_label: string;
  code_placeholder: string;
  delivery_help: string;
  form: { action: string; submit_label: string };
  cancel_link: IdentityLink;
  errors: string[];
};

export default function TelephoneRegistrationEdit({
  title,
  description,
  code_label: codeLabel,
  code_placeholder: codePlaceholder,
  delivery_help: deliveryHelp,
  form,
  cancel_link: cancelLink,
  errors,
}: Props) {
  const [passCode, setPassCode] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      { user_telephone: { pass_code: passCode } },
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
            id="user_telephone_pass_code"
            label={codeLabel}
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            autoComplete="one-time-code"
            placeholder={codePlaceholder}
            description={deliveryHelp}
            value={passCode}
            onChange={setPassCode}
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
