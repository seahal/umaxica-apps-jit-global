import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";

type Props = {
  title: string;
  notices: string[];
  form: { action: string; jurisdiction: string; submit_label: string };
};

export default function PrivacyErasureNew({ title, notices, form }: Props) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.action,
      { jurisdiction: form.jurisdiction },
      {
        onStart: () => setProcessing(true),

        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <Page
      title={title}
      width="narrow"
    >
      <div className="flex flex-col gap-3 text-base text-fg-muted">
        {notices.map((notice) => (
          <p key={notice}>{notice}</p>
        ))}
      </div>

      <form onSubmit={submit}>
        <Button
          type="submit"
          variant="danger"
          isDisabled={processing}
        >
          {form.submit_label}
        </Button>
      </form>
    </Page>
  );
}
