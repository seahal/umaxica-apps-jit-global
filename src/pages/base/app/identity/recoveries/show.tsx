import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import Select from "@/components/ui/Select";
import TextField from "@/components/ui/TextField";

type AppealForm = {
  url: string;
  reason_label: string;
  reason_codes: { label: string; value: string }[];
  statement_label: string;
  statement_max_length: number;
  submit_label: string;
};

type EnforcementCase = {
  public_id: string;
  kind_label: string;
  restore: { url: string; submit_label: string };
  appeal: AppealForm | null;
};

type Props = {
  title: string;
  description: string;
  appeal_error: string | null;
  enforcement_cases: EnforcementCase[];
};

function AppealSection({ form, casePublicId }: { form: AppealForm; casePublicId: string }) {
  const [reasonCode, setReasonCode] = useState(form.reason_codes[0]?.value ?? "");
  const [statement, setStatement] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    router.post(
      form.url,
      {
        appeal: {
          enforcement_case_id: casePublicId,
          reason_code: reasonCode,
          statement,
        },
      },
      {
        onStart: () => setProcessing(true),

        onFinish: () => setProcessing(false),
      },
    );
  };

  return (
    <form
      onSubmit={submit}
      className="flex flex-col gap-4"
    >
      <Select
        id={`appeal_reason_code_${casePublicId}`}
        label={form.reason_label}
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
        id={`appeal_statement_${casePublicId}`}
        label={form.statement_label}
        multiline
        maxLength={form.statement_max_length}
        value={statement}
        onChange={setStatement}
      />

      <Button
        type="submit"
        isDisabled={processing}
      >
        {form.submit_label}
      </Button>
    </form>
  );
}

export default function RecoveryShow({
  title,
  description,
  appeal_error: appealError,
  enforcement_cases: enforcementCases,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
    >
      <ErrorList errors={appealError === null ? [] : [appealError]} />

      {enforcementCases.map((enforcementCase) => (
        <Card
          key={enforcementCase.public_id}
          heading={enforcementCase.kind_label}
        >
          <form
            onSubmit={(event) => {
              event.preventDefault();
              router.post(enforcementCase.restore.url, {
                data: { enforcement_case_id: enforcementCase.public_id },
              });
            }}
          >
            <Button type="submit">{enforcementCase.restore.submit_label}</Button>
          </form>

          {enforcementCase.appeal ? (
            <AppealSection
              form={enforcementCase.appeal}
              casePublicId={enforcementCase.public_id}
            />
          ) : null}
        </Card>
      ))}
    </Page>
  );
}
