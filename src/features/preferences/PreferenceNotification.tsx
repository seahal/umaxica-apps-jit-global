// Mock notification settings screen. The form has no fields yet; submitting it sends an empty
// PATCH so the edit -> update round trip already works while the settings are designed.
import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Select from "@/components/ui/Select";
import PreferenceScreenFrame, {
  type PreferenceLink,
} from "@/features/preferences/PreferenceScreenFrame";

type PreferenceNotificationForm = {
  action: string;
  method: string;
  /** Rails parameter wrapper, `preference_notification`. */
  scope: string;
  submit_label: string;
  submitting_label: string;
};

type PreferenceNotificationChoice = {
  value: string;
  label: string;
};

/** Display only for now: the value is kept in the page and is not submitted. */
type PreferenceNotificationWebPush = {
  label: string;
  value: string;
  choices: PreferenceNotificationChoice[];
};

export type PreferenceNotificationProps = {
  title: string;
  description: string;
  placeholder: string;
  back_link: PreferenceLink;
  form: PreferenceNotificationForm;
  web_push: PreferenceNotificationWebPush;
};

export default function PreferenceNotification({
  title,
  description,
  placeholder,
  back_link: backLink,
  form,
  web_push: webPush,
}: PreferenceNotificationProps) {
  const [processing, setProcessing] = useState(false);
  const [webPushValue, setWebPushValue] = useState(webPush.value);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.patch(
      form.action,
      { [form.scope]: {} },
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <PreferenceScreenFrame
      title={title}
      description={description}
      back_link={backLink}
    >
      <form
        onSubmit={submit}
        method="post"
        action={form.action}
        className="flex flex-col gap-4"
      >
        <p>{placeholder}</p>
        <Select
          label={webPush.label}
          value={webPushValue}
          onChange={(next) => {
            setWebPushValue(next);
          }}
          options={webPush.choices.map((choice) => ({ value: choice.value, label: choice.label }))}
        />
        <Button
          type="submit"
          isDisabled={processing}
        >
          {processing ? form.submitting_label : form.submit_label}
        </Button>
      </form>
    </PreferenceScreenFrame>
  );
}
