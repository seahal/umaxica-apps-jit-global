import { router } from "@inertiajs/react";
import { useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";

type Candidate = {
  account_public_id: string;
  organization_public_id: string;
  organization_unit_public_id: string;
};

type Props = {
  title: string;
  description: string;
  account_label: string;
  organization_label: string;
  unit_label: string;
  submit_label: string;
  empty_message: string;
  action: string;
  candidates: Candidate[];
  error: string | null;
};

function candidateKey(candidate: Candidate) {
  return [
    candidate.account_public_id,
    candidate.organization_public_id,
    candidate.organization_unit_public_id,
  ].join("/");
}

export default function SelectorShow({
  title,
  description,
  account_label: accountLabel,
  organization_label: organizationLabel,
  unit_label: unitLabel,
  submit_label: submitLabel,
  empty_message: emptyMessage,
  action,
  candidates,
  error,
}: Props) {
  const [selected, setSelected] = useState("");
  const [processing, setProcessing] = useState(false);

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const candidate = candidates.find((item) => candidateKey(item) === selected);
    if (candidate === undefined) {
      return;
    }

    router.patch(action, candidate, {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    });
  };

  return (
    <Page title={title} description={description} width="narrow">
      <ErrorList errors={error === null ? [] : [error]} />

      <Card>
        {candidates.length === 0 ? (
          <p className="text-base text-fg-muted">{emptyMessage}</p>
        ) : (
          <form onSubmit={submit} className="flex flex-col gap-4">
            <fieldset className="flex flex-col gap-3">
              <legend className="text-base font-medium text-fg">{description}</legend>
              {candidates.map((candidate) => {
                const key = candidateKey(candidate);
                return (
                  <label
                    key={key}
                    className="flex cursor-pointer gap-3 rounded-lg border border-line p-4 text-sm text-fg"
                  >
                    <input
                      type="radio"
                      name="organization"
                      value={key}
                      checked={selected === key}
                      onChange={() => setSelected(key)}
                      required
                    />
                    <span className="flex flex-col gap-1 break-all">
                      <span>
                        {accountLabel}: {candidate.account_public_id}
                      </span>
                      <span>
                        {organizationLabel}: {candidate.organization_public_id}
                      </span>
                      <span>
                        {unitLabel}: {candidate.organization_unit_public_id}
                      </span>
                    </span>
                  </label>
                );
              })}
            </fieldset>
            <Button type="submit" isDisabled={processing || selected.length === 0}>
              {submitLabel}
            </Button>
          </form>
        )}
      </Card>
    </Page>
  );
}
