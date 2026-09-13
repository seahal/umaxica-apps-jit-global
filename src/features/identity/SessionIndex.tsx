// The session inventory of an identity surface.
//
// Which sessions may be revoked is a server decision: the current session arrives without a
// `revoke` action, and the bulk revocations are absent when there is no other session to revoke.

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import { csrfToken } from "@/lib/csrf";

export type SessionAction = {
  label: string;
  href: string;
  confirm: string;
};

export type SessionRow = {
  public_id: string;
  current: boolean;
  current_label: string | null;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  revoke: SessionAction | null;
};

export type SessionIndexProps = {
  title: string;
  back_link: { label: string; href: string };
  empty_message: string;
  columns: {
    session: string;
    kind: string;
    binding: string;
    last_activity: string;
    created: string;
    refresh_expires: string;
  };
  bulk_revocations: { others: SessionAction } | null;
  sessions: SessionRow[];
};

// Revocation stays a DELETE submitted as a document, exactly as `button_to` did: it ends session
// state the current page depends on, so the server's redirect drives the next screen.
function RevokeButton({ action }: { action: SessionAction }) {
  const { confirm, dialog } = useConfirm();

  // The confirmation is asynchronous now, so the submission is held back and replayed with
  // `submit()`, which sends the same document POST without running this handler again.
  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm({ message: action.confirm, confirmLabel: action.label }, () => form.submit());
  };

  return (
    <>
      <form
        action={action.href}
        method="post"
        data-turbo="false"
        onSubmit={submit}
      >
        <input
          type="hidden"
          name="_method"
          value="delete"
        />
        <input
          type="hidden"
          name="authenticity_token"
          value={csrfToken()}
        />
        <Button
          type="submit"
          variant="danger"
          size="sm"
        >
          {action.label}
        </Button>
      </form>
      {dialog}
    </>
  );
}

export default function SessionIndex({
  title,
  back_link: backLink,
  empty_message: emptyMessage,
  columns,
  bulk_revocations: bulkRevocations,
  sessions,
}: SessionIndexProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
      width="wide"
    >
      {bulkRevocations ? (
        <div className="flex flex-wrap gap-2">
          <RevokeButton action={bulkRevocations.others} />
        </div>
      ) : null}

      {sessions.length > 0 ? (
        <Table>
          <thead>
            <tr>
              <th scope="col">{columns.session}</th>
              <th scope="col">{columns.kind}</th>
              <th scope="col">{columns.binding}</th>
              <th scope="col">{columns.last_activity}</th>
              <th scope="col">{columns.created}</th>
              <th scope="col">{columns.refresh_expires}</th>
              <th scope="col" />
            </tr>
          </thead>
          <tbody>
            {sessions.map((session) => (
              <tr
                key={session.public_id}
                className={
                  session.current
                    ? "border-t border-line bg-surface-muted font-semibold"
                    : "border-t border-line bg-surface"
                }
              >
                <td>
                  <div className="flex flex-col gap-0.5">
                    <span>{session.public_id}</span>
                    {session.current_label ? (
                      <span className="text-xs font-normal text-fg-muted">
                        {session.current_label}
                      </span>
                    ) : null}
                  </div>
                  <p className="text-xs font-normal text-fg-muted">{session.status}</p>
                </td>
                <td>{session.kind}</td>
                <td>{session.binding}</td>
                <td>{session.last_activity}</td>
                <td>{session.created}</td>
                <td>{session.refresh_expires}</td>
                <td>{session.revoke ? <RevokeButton action={session.revoke} /> : null}</td>
              </tr>
            ))}
          </tbody>
        </Table>
      ) : (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      )}
    </Page>
  );
}
