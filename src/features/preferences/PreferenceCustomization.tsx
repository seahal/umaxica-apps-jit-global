import { router, usePage } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import PreferenceScreenFrame, {
  type PreferenceLink,
} from "@/features/preferences/PreferenceScreenFrame";

type PreferenceCustomizationForm = {
  action: string;
  method: string;
  field: string;
  label: string;
  value: boolean;
  submit_label: string;
  submitting_label: string;
};

export type PreferenceCustomizationProps = {
  screen: string;
  title: string;
  description: string;
  back_link: PreferenceLink;
  form: PreferenceCustomizationForm;
};

// Resetting is destructive, so the server refuses an unconfirmed request and sends the screen back
// with an error rather than trusting the disabled state of this button.
export default function PreferenceCustomization({
  title,
  description,
  back_link: backLink,
  form,
}: PreferenceCustomizationProps) {
  const [confirmed, setConfirmed] = useState(form.value);
  const [processing, setProcessing] = useState(false);
  const { errors } = usePage().props;
  const error = errors[form.field];

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.delete(form.action, {
      data: { [form.field]: confirmed ? "1" : "" },
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <PreferenceScreenFrame
      title={title}
      description={description}
      back_link={backLink}
    >
      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        {error ? (
          <ul className="flex flex-col gap-1 text-base text-error">
            <li role="alert">{error}</li>
          </ul>
        ) : null}

        <Checkbox
          name={form.field}
          isRequired
          isSelected={confirmed}
          onChange={(isSelected: boolean) => setConfirmed(isSelected)}
        >
          {form.label}
        </Checkbox>

        <div>
          <Button
            type="submit"
            variant="danger"
            isDisabled={processing}
          >
            {processing ? form.submitting_label : form.submit_label}
          </Button>
        </div>
      </form>
    </PreferenceScreenFrame>
  );
}
