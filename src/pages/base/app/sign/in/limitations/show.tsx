import { router, useForm } from "@inertiajs/react";
import type { SyntheticEvent } from "react";

import Button from "@/components/ui/Button";
import ErrorList from "@/components/ui/ErrorList";
import Page from "@/components/ui/Page";

type SessionEntry = {
  session_ref: string;
  restriction_label: string;
  created_label: string;
  last_used_label: string | null;
  revoke_label: string;
};

type Props = {
  title: string;
  heading: string;
  description: string;
  session_label: string;
  error: string | null;
  notice: string | null;
  action: string;
  cancel_action: string;
  submit_label: string;
  cancel_label: string;
  // The server decides which resolution channel this ceremony runs on and names the field. A
  // sign-in flow held by this browser's session needs no field: the browser itself is the binding.
  resolution: { field: string; value: string } | null;
  sessions: SessionEntry[];
};

export default function SignInLimitationShow({
  heading,
  description,
  session_label: sessionLabel,
  error,
  notice,
  action,
  cancel_action: cancelAction,
  submit_label: submitLabel,
  cancel_label: cancelLabel,
  resolution,
  sessions,
}: Props) {
  const form = useForm<{ session_ref: string } & Record<string, string>>({
    session_ref: "",
    ...(resolution ? { [resolution.field]: resolution.value } : {}),
  });
  const { data, setData, errors, processing } = form;

  const submit = (event: SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    form.patch(action);
  };

  return (
    <Page
      title={heading}
      description={description}
    >
      <ErrorList
        errors={[error, errors["session_ref"]].filter(
          (message): message is string => typeof message === "string" && message.length > 0,
        )}
      />

      {notice ? <p className="text-base text-fg-muted">{notice}</p> : null}

      <form
        onSubmit={submit}
        className="flex flex-col gap-4"
      >
        <ul className="flex flex-col gap-2">
          {sessions.map((entry) => (
            <li key={entry.session_ref}>
              {/*
                The whole row is the label, so the radio and the session it revokes are one target
                rather than a control the visitor has to hit separately.
              */}
              <label
                className="flex cursor-pointer gap-3 rounded-lg border border-line bg-surface p-4
                  text-base has-checked:border-accent"
              >
                <input
                  type="radio"
                  name="session_ref"
                  value={entry.session_ref}
                  checked={data.session_ref === entry.session_ref}
                  onChange={() => setData("session_ref", entry.session_ref)}
                  className="mt-0.5"
                />
                <span className="flex flex-col gap-1">
                  <span className="font-medium text-fg">
                    {sessionLabel} <span>{entry.restriction_label}</span>
                  </span>
                  <span className="text-fg-muted">{entry.created_label}</span>
                  {entry.last_used_label ? (
                    <span className="text-fg-muted">{entry.last_used_label}</span>
                  ) : null}
                  <span className="text-fg">{entry.revoke_label}</span>
                </span>
              </label>
            </li>
          ))}
        </ul>

        <div className="flex flex-wrap items-center gap-3">
          <Button
            type="submit"
            variant="danger"
            isDisabled={processing}
          >
            {submitLabel}
          </Button>

          <Button
            type="button"
            variant="secondary"
            onPress={() => router.delete(cancelAction)}
          >
            {cancelLabel}
          </Button>
        </div>
      </form>
    </Page>
  );
}
