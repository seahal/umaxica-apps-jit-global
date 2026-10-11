import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import Select from "@/components/ui/Select";
import TextField from "@/components/ui/TextField";

// Replaces `app/views/base/com/identity/recoveries/show.html.erb`. Whether a case may be appealed
// is decided on the server: an unappealable case simply arrives without an appeal form.

export type RecoveryAppealForm = {
  url: string;
  scope: string;
  reason_label: string;
  reason_codes: { label: string; value: string }[];
  statement_label: string;
  statement_max_length: number;
  submit_label: string;
};

export type RecoveryCase = {
  public_id: string;
  kind_label: string;
  restore: { url: string; submit_label: string };
  appeal: RecoveryAppealForm | null;
};

export type EnforcementRecoveryShowProps = {
  title: string;
  description: string;
  appeal_error: string | null;
  enforcement_cases: RecoveryCase[];
};

function RestoreForm({
  action,
  enforcementCaseId,
}: {
  action: { url: string; submit_label: string };
  enforcementCaseId: string;
}) {
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      action.url,
      { enforcement_case_id: enforcementCaseId },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <form onSubmit={submit}>
      <Button
        type="submit"
        size="sm"
        isDisabled={processing}
      >
        {action.submit_label}
      </Button>
    </form>
  );
}

function AppealForm({
  form,
  enforcementCaseId,
}: {
  form: RecoveryAppealForm;
  enforcementCaseId: string;
}) {
  const [reasonCode, setReasonCode] = useState(form.reason_codes[0]?.value ?? "");
  const [statement, setStatement] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        [form.scope]: {
          enforcement_case_id: enforcementCaseId,
          reason_code: reasonCode,
          statement,
        },
      },
      { onStart: () => setProcessing(true), onFinish: () => setProcessing(false) },
    );
  };

  return (
    <form
      onSubmit={submit}
      className="flex flex-col gap-4"
    >
      <Select
        label={form.reason_label}
        name={`${form.scope}[reason_code]`}
        options={form.reason_codes}
        value={reasonCode}
        onChange={(value) => {
          /* v8 ignore next -- React Aria reports null only when the selection is cleared */
          if (value !== null) {
            setReasonCode(String(value));
          }
        }}
      />

      <TextField
        label={form.statement_label}
        name={`${form.scope}[statement]`}
        multiline
        maxLength={form.statement_max_length}
        value={statement}
        onChange={setStatement}
      />

      <Button
        type="submit"
        size="sm"
        isDisabled={processing}
        className="w-fit"
      >
        {form.submit_label}
      </Button>
    </form>
  );
}

export default function EnforcementRecoveryShow({
  title,
  description,
  appeal_error: appealError,
  enforcement_cases: enforcementCases,
}: EnforcementRecoveryShowProps) {
  return (
    <Page
      title={title}
      description={description}
    >
      {appealError ? (
        <p
          role="alert"
          className="rounded-md border border-danger bg-surface p-3 text-sm text-danger"
        >
          {appealError}
        </p>
      ) : null}

      {enforcementCases.map((enforcementCase) => (
        <section
          key={enforcementCase.public_id}
          className="flex flex-col gap-3 rounded-lg border border-line bg-surface p-4"
        >
          <p className="text-sm font-medium text-fg">{enforcementCase.kind_label}</p>
          <RestoreForm
            action={enforcementCase.restore}
            enforcementCaseId={enforcementCase.public_id}
          />
          {enforcementCase.appeal ? (
            <AppealForm
              form={enforcementCase.appeal}
              enforcementCaseId={enforcementCase.public_id}
            />
          ) : null}
        </section>
      ))}
    </Page>
  );
}
