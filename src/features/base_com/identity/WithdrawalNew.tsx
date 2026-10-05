import { router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Checkbox from "@/components/ui/Checkbox";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/withdrawals/new.html.erb`. The deactivation step is absent
// from the props until the schedule has been acknowledged, so the gate stays a server decision.

export type WithdrawalAckForm = {
  title: string;
  errors: string[];
  url: string;
  method: "get" | "patch";
  field: string;
  ack_label: string;
  checked?: boolean;
  submit_label: string;
  confirm?: string;
};

export type WithdrawalNewProps = {
  title: string;
  already_deactivated: boolean;
  already_deactivated_message: string;
  recovery_link: PageLink;
  schedule: WithdrawalAckForm;
  deactivate: WithdrawalAckForm | null;
};

function AckSection({ form }: { form: WithdrawalAckForm }) {
  const [checked, setChecked] = useState(form.checked ?? false);
  const [processing, setProcessing] = useState(false);
  const { confirm: requestConfirmation, dialog } = useConfirm();

  const send = () => {
    const payload = { [form.field]: checked ? "1" : "0" };
    const options = {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    };

    if (form.method === "patch") {
      router.patch(form.url, payload, options);
    } else {
      router.get(form.url, payload, options);
    }
  };

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    // The acknowledgement step the server sent no confirmation copy for was never gated by one.
    if (form.confirm) {
      requestConfirmation({ message: form.confirm, confirmLabel: form.submit_label }, send);
      return;
    }
    send();
  };

  return (
    <section className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4">
      <h2 className="text-xl font-semibold text-fg">{form.title}</h2>
      <ErrorList errors={form.errors} />

      <form
        onSubmit={submit}
        className="flex flex-col gap-3"
      >
        <Checkbox
          id={form.field}
          isSelected={checked}
          onChange={setChecked}
        >
          {form.ack_label}
        </Checkbox>
        <div>
          <Button
            type="submit"
            isDisabled={processing}
          >
            {form.submit_label}
          </Button>
        </div>
      </form>
      {dialog}
    </section>
  );
}

export default function WithdrawalNew({
  title,
  already_deactivated: alreadyDeactivated,
  already_deactivated_message: alreadyDeactivatedMessage,
  recovery_link: recoveryLink,
  schedule,
  deactivate,
}: WithdrawalNewProps) {
  return (
    <Page title={title}>
      {alreadyDeactivated ? (
        <>
          <p className="text-base text-fg-muted">{alreadyDeactivatedMessage}</p>
          <p>
            <TextLink
              href={recoveryLink.href}
              inertia
              tone="muted"
            >
              {recoveryLink.label}
            </TextLink>
          </p>
        </>
      ) : (
        <div className="flex flex-col gap-4">
          <AckSection form={schedule} />
          {deactivate ? <AckSection form={deactivate} /> : null}
        </div>
      )}
    </Page>
  );
}
