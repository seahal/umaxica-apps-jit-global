// The confirmation screen for one administrative mutation. It restates the operator, realm,
// target, the target's current state, and what the operation will do, then submits only the fixed
// fields the server listed. The operation id is issued by the server for this screen, so a
// resubmission is recognised as the same operation and a different target never reuses it.
import { useForm } from "@inertiajs/react";
import { type SyntheticEvent, useId, useState } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Checkbox from "@/components/ui/Checkbox";
import DescriptionList from "@/components/ui/DescriptionList";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";
import Select from "@/components/ui/Select";
import TextField from "@/components/ui/TextField";

import AdminContextPanel, { AdminNotices } from "./AdminContextPanel";
import type { AdminBaseProps, AdminField } from "./types";

export type AdminConfirmationField =
  | {
      kind: "select";
      name: string;
      label: string;
      value: string;
      options: { value: string; label: string }[];
    }
  | {
      kind: "text";
      name: string;
      label: string;
      value: string;
      maxlength: number;
      required: boolean;
    }
  | { kind: "hidden"; name: string; value: string };

export type AdminConfirmationProps = AdminBaseProps & {
  target: AdminField[];
  effect: string;
  action: string;
  fields: AdminConfirmationField[];
  acknowledgement: string;
  submit_label: string;
  errors?: Record<string, string>;
};

// Field names such as `enforcement_case[kind]` are sent as nested objects, the shape Rails strong
// parameters expect from a JSON body. Only one level of nesting is used by any screen.
type NestedFields = Record<string, string | Record<string, string>>;

export function nestFieldNames(data: Record<string, string>): NestedFields {
  const nested: NestedFields = {};
  for (const [name, value] of Object.entries(data)) {
    const match = /^(?<root>[a-z_]+)\[(?<child>[a-z_]+)\]$/u.exec(name);
    const root = match?.groups?.["root"];
    const child = match?.groups?.["child"];
    if (root === undefined || child === undefined) {
      nested[name] = value;
      continue;
    }
    const existing = nested[root];
    const group = typeof existing === "object" ? existing : {};
    group[child] = value;
    nested[root] = group;
  }
  return nested;
}

export default function AdminConfirmation({
  title,
  description,
  up_link: upLink = null,
  context,
  notices = [],
  target,
  effect,
  action,
  fields,
  acknowledgement,
  submit_label: submitLabel,
}: AdminConfirmationProps) {
  const initial = Object.fromEntries(fields.map((field) => [field.name, field.value]));
  const form = useForm<Record<string, string>>(initial);
  const { data, setData, errors, processing } = form;
  const [acknowledged, setAcknowledged] = useState(false);
  const errorMessages = Object.values(errors);
  const disabledReasonId = useId();
  const disabledReason =
    typeof document === "undefined"
      ? undefined
      : document.querySelector<HTMLMetaElement>(
          `meta[name="${processing ? "ui-processing" : "ui-confirmation-required"}"]`,
        )?.content;

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!acknowledged) {
      return;
    }

    form.transform((current) => nestFieldNames(current));
    form.post(action);
  };

  return (
    <Page
      title={title}
      {...(description ? { description } : {})}
      up={upLink}
      upVisit="document"
    >
      <AdminContextPanel context={context} />
      <AdminNotices notices={notices} />

      <Card>
        <DescriptionList items={target} />
        <p className="mt-3 text-base text-fg">{effect}</p>
      </Card>

      {errorMessages.length > 0 ? (
        <ErrorList
          announce
          errors={errorMessages}
        />
      ) : null}

      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        {fields.map((field) => {
          if (field.kind === "select") {
            return (
              <Select
                key={field.name}
                label={field.label}
                options={field.options}
                value={data[field.name] ?? ""}
                onChange={(value) => {
                  setData(field.name, value);
                }}
              />
            );
          }
          if (field.kind === "text") {
            return (
              <TextField
                key={field.name}
                label={field.label}
                name={field.name}
                maxLength={field.maxlength}
                isRequired={field.required}
                value={data[field.name] ?? ""}
                onChange={(value) => setData(field.name, value)}
              />
            );
          }
          // Hidden fields travel in the form data only.
          return null;
        })}

        <Checkbox
          isSelected={acknowledged}
          onChange={setAcknowledged}
        >
          {acknowledgement}
        </Checkbox>

        <div>
          <Button
            type="submit"
            isDisabled={processing || !acknowledged}
            {...((processing || !acknowledged) && disabledReason
              ? { "aria-describedby": disabledReasonId }
              : {})}
          >
            {submitLabel}
          </Button>
          {(processing || !acknowledged) && disabledReason ? (
            <p
              id={disabledReasonId}
              className="mt-2 text-base text-fg-muted"
            >
              {disabledReason}
            </p>
          ) : null}
        </div>
      </form>
    </Page>
  );
}
