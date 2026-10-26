import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import type { IdentityLink } from "@/types/identity";

type SecurityModeForm = { action: string; security_mode_id: number; submit_label: string };

type Props = {
  title: string;
  reset_unavailable: string;
  toggle_title: string;
  state_label: string;
  back_link: IdentityLink;
  form: SecurityModeForm | null;
  form_unavailable: string | null;
  error: string | null;
};

export default function ComMfaChallengeShow({
  title,
  reset_unavailable: resetUnavailable,
  toggle_title: toggleTitle,
  state_label: stateLabel,
  back_link: backLink,
  form,
  form_unavailable: formUnavailable,
  error,
}: Props) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (form === null) {
      return;
    }
    router.patch(
      form.action,
      { user: { security_mode_id: form.security_mode_id } },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <Page
      title={title}
      description={resetUnavailable}
      up={backLink}
      width="narrow"
    >
      <ErrorList errors={error === null ? [] : [error]} />

      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3 text-base">
          <span className="font-medium text-fg">{toggleTitle}</span>
          <span className="text-fg-muted">{stateLabel}</span>
        </div>
        {form === null ? (
          <p className="mt-3 text-sm text-fg-muted">{formUnavailable}</p>
        ) : (
          <form
            onSubmit={submit}
            className="mt-4"
          >
            <Button
              type="submit"
              isDisabled={processing}
            >
              {form.submit_label}
            </Button>
          </form>
        )}
      </Card>
    </Page>
  );
}
