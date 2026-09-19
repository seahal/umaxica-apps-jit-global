import { useForm } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";

// The session-limit management page.
//
// A visitor who reached the concurrent session limit lands here with a restricted session and has
// to revoke one of their active sessions to continue. Selecting a session and cancelling the
// sign-in are both state-changing, so they keep the PATCH and DELETE verbs the route expects.
export type SessionItem = {
  label: string;
  current: boolean;
  current_label: string | null;
  created_at_label: string;
  created_at: string;
  last_used_at_label: string | null;
  last_used_at: string | null;
  ref: string | null;
};

export type ActiveSessionGroup = {
  heading: string;
  count_label: string;
  revoke_label: string;
  items: SessionItem[];
};

export type RestrictedSessionGroup = {
  heading: string;
  items: SessionItem[];
};

export type SessionLimitManagerProps = {
  title: string;
  heading: string;
  description: string;
  alert: string | null;
  notice: string | null;
  restricted_notice: string | null;
  form: {
    action: string;
    submit_label: string;
  };
  cancel: {
    action: string;
    label: string;
    confirm: string;
  };
  active_sessions: ActiveSessionGroup | null;
  restricted_sessions: RestrictedSessionGroup | null;
};

function SessionTimestamps({ item }: { item: SessionItem }) {
  return (
    <>
      <p className="text-xs text-fg-muted">
        {item.created_at_label}: {item.created_at}
      </p>
      {item.last_used_at_label && item.last_used_at ? (
        <p className="text-xs text-fg-muted">
          {item.last_used_at_label}: {item.last_used_at}
        </p>
      ) : null}
    </>
  );
}

export default function SessionLimitManager({
  heading,
  description,
  alert,
  notice,
  restricted_notice: restrictedNotice,
  form,
  cancel,
  active_sessions: activeSessions,
  restricted_sessions: restrictedSessions,
}: SessionLimitManagerProps) {
  const [selectedRef, setSelectedRef] = useState("");
  const revocation = useForm({ ref: "" });
  const cancellation = useForm({});
  const { confirm, dialog } = useConfirm();

  const submitRevocation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    // `transform` returns void in Inertia 3, so the request is issued separately rather than
    // chained off it.
    revocation.transform(() => ({ ref: selectedRef }));
    revocation.patch(form.action);
  };

  const submitCancellation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    confirm({ message: cancel.confirm, confirmLabel: cancel.label }, () => {
      cancellation.delete(cancel.action);
    });
  };

  return (
    <section className="flex flex-col gap-6">
      <h1 className="text-2xl font-bold text-fg">{heading}</h1>

      {alert ? (
        <div
          role="alert"
          className="rounded-md border border-line bg-surface p-4 text-sm text-danger"
        >
          <p>{alert}</p>
        </div>
      ) : null}

      {notice ? (
        <output className="rounded-md border border-line bg-surface p-4 text-sm text-fg">
          <p>{notice}</p>
        </output>
      ) : null}

      {restrictedNotice ? <p className="text-sm text-fg-muted">{restrictedNotice}</p> : null}

      <p className="text-sm text-fg-muted">{description}</p>

      <form
        action={form.action}
        method="post"
        onSubmit={submitRevocation}
        className="flex flex-col gap-6"
      >
        {activeSessions ? (
          <section className="flex flex-col gap-3">
            <h2 className="text-lg font-semibold text-fg">
              {activeSessions.heading}{" "}
              <span className="text-sm font-normal text-fg-muted">
                {activeSessions.count_label}
              </span>
            </h2>
            <ul className="flex flex-col gap-3">
              {activeSessions.items.map((item, index) => {
                const sessionRef = item.ref;
                return (
                  <li
                    key={sessionRef ?? `current-${index}`}
                    className="flex flex-col gap-2 rounded-lg border border-line bg-surface p-4"
                  >
                    <div className="flex flex-col gap-1">
                      <p className="text-sm font-medium text-fg">
                        {item.label}
                        {item.current_label ? (
                          <span className="ml-2 text-xs font-medium text-accent">
                            {item.current_label}
                          </span>
                        ) : null}
                      </p>
                      <SessionTimestamps item={item} />
                    </div>
                    {sessionRef ? (
                      <label className="flex items-center gap-2 text-sm text-fg">
                        <input
                          type="radio"
                          name="ref"
                          value={sessionRef}
                          checked={selectedRef === sessionRef}
                          onChange={() => setSelectedRef(sessionRef)}
                        />
                        <span>{activeSessions.revoke_label}</span>
                      </label>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          </section>
        ) : null}

        {restrictedSessions ? (
          <section className="flex flex-col gap-3">
            <h2 className="text-lg font-semibold text-fg">{restrictedSessions.heading}</h2>
            <ul className="flex flex-col gap-3">
              {restrictedSessions.items.map((item, index) => (
                <li
                  key={`restricted-${index}`}
                  className="flex flex-col gap-2 rounded-lg border border-line bg-surface p-4"
                >
                  <div className="flex flex-col gap-1">
                    <p className="text-sm font-medium text-fg">
                      {item.label}
                      {item.current_label ? (
                        <span className="ml-2 text-xs font-medium text-accent">
                          {item.current_label}
                        </span>
                      ) : null}
                    </p>
                    <p className="text-xs text-fg-muted">
                      {item.created_at_label}: {item.created_at}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </section>
        ) : null}

        <Button
          type="submit"
          isDisabled={revocation.processing}
          className="self-start"
        >
          {form.submit_label}
        </Button>
      </form>

      <form
        action={cancel.action}
        method="post"
        onSubmit={submitCancellation}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
        />
        <Button
          type="submit"
          variant="danger"
          isDisabled={cancellation.processing}
        >
          {cancel.label}
        </Button>
      </form>
      {dialog}
    </section>
  );
}
