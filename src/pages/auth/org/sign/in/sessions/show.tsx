// Session-limit management for an operator whose sign-in exceeded the concurrent session limit.
//
// Both forms are document submissions, as the ERB forms were: PATCH revokes the selected session
// and may promote the restricted one, DELETE cancels the ceremony and signs the operator out. The
// value on each choice is the server's signed reference, which is all the server accepts.
import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

type SessionRow = {
  ref: string;
  digest: string;
  created_at: string | null;
  last_used_at: string | null;
};

export type OrgSessionLimitPageProps = {
  title: string;
  heading: string;
  description: string;
  form_action: string;
  active_sessions_heading: string;
  session_label: string;
  created_at_label: string;
  last_used_label: string;
  no_sessions: string;
  submit_label: string;
  cancel_logout_label: string;
  cancel_logout_confirm: string;
  sessions: SessionRow[];
};

export default function OrgSessionLimitPage({
  heading,
  description,
  form_action: formAction,
  active_sessions_heading: activeSessionsHeading,
  session_label: sessionLabel,
  created_at_label: createdAtLabel,
  last_used_label: lastUsedLabel,
  no_sessions: noSessions,
  submit_label: submitLabel,
  cancel_logout_label: cancelLogoutLabel,
  cancel_logout_confirm: cancelLogoutConfirm,
  sessions,
}: OrgSessionLimitPageProps) {
  const { confirm, dialog } = useConfirm();

  // The cancellation is held back until the operator accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submitCancellation = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm({ message: cancelLogoutConfirm, confirmLabel: cancelLogoutLabel }, () => form.submit());
  };

  return (
    // No link back to the sign-in form: authentication has already succeeded and a restricted
    // session exists, so the only way out of this page is the DELETE cancellation below.
    <Page
      title={heading}
      description={description}
    >
      <form
        action={formAction}
        method="post"
      >
        <input
          type="hidden"
          name="_method"
          value="patch"
          readOnly
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />

        <Card heading={activeSessionsHeading}>
          {sessions.length > 0 ? (
            <ul className="flex flex-col gap-2">
              {sessions.map((session) => (
                <li key={session.ref}>
                  {/*
                    The whole row is the label, so the radio and the session it revokes are one
                    target. The selected row is marked by its border rather than a ring, which is
                    what the focus outline already uses.
                  */}
                  <label
                    data-session-checkbox
                    className="flex cursor-pointer gap-3 rounded-lg border border-line
                      bg-surface p-4 text-base has-checked:border-accent"
                  >
                    <input
                      type="radio"
                      name="ref"
                      value={session.ref}
                      className="mt-0.5"
                    />
                    <span className="flex flex-col gap-1">
                      <span className="font-medium text-fg">
                        {sessionLabel} #{session.digest}
                      </span>
                      <span className="text-fg-muted">
                        {createdAtLabel}: {session.created_at}
                      </span>
                      {session.last_used_at ? (
                        <span className="text-fg-muted">
                          {lastUsedLabel}: {session.last_used_at}
                        </span>
                      ) : null}
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-base text-fg-muted">{noSessions}</p>
          )}

          <Button type="submit">{submitLabel}</Button>
        </Card>
      </form>

      <form
        action={formAction}
        method="post"
        onSubmit={submitCancellation}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
          readOnly
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
          readOnly
        />
        <Button
          type="submit"
          variant="secondary"
        >
          {cancelLogoutLabel}
        </Button>
      </form>
      {dialog}
    </Page>
  );
}
