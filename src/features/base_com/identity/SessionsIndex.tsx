import { router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import type { ConfirmedAction, PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/sessions/index.html.erb`. Which revocations are offered is
// a server decision: an action the actor may not take is absent from the props rather than hidden.

export type SessionRow = {
  public_id: string;
  current: boolean;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  revoke: ConfirmedAction | null;
};

export type SessionsIndexProps = {
  title: string;
  back_link: PageLink;
  columns: string[];
  empty_message: string;
  current_label: string;
  bulk_actions: { revoke_others: ConfirmedAction } | null;
  sessions: SessionRow[];
};

function RevokeButton({ action }: { action: ConfirmedAction }) {
  const [processing, setProcessing] = useState(false);
  const { confirm, dialog } = useConfirm();

  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    confirm({ message: action.confirm, confirmLabel: action.label }, () => {
      router.delete(action.url, {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
      });
    });
  };

  return (
    <>
      <form
        onSubmit={submit}
        className="inline-flex"
      >
        <Button
          type="submit"
          variant="danger"
          size="sm"
          isDisabled={processing}
        >
          {action.label}
        </Button>
      </form>
      {dialog}
    </>
  );
}

export default function SessionsIndex({
  title,
  back_link: backLink,
  columns,
  empty_message: emptyMessage,
  current_label: currentLabel,
  bulk_actions: bulkActions,
  sessions,
}: SessionsIndexProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
    >
      {bulkActions ? (
        <div className="flex flex-wrap gap-3">
          <RevokeButton action={bulkActions.revoke_others} />
        </div>
      ) : null}

      {sessions.length > 0 ? (
        <Table>
          <thead>
            <tr>
              {columns.map((column, index) => (
                // Column labels are server text and one of them is deliberately blank, so the
                // position is the only stable key.
                <th key={`${column}-${index}`}>{column}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {sessions.map((session) => (
              <tr
                key={session.public_id}
                className={
                  session.current
                    ? "border-b border-line bg-surface-muted last:border-0"
                    : "border-b border-line last:border-0"
                }
              >
                <td>
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-fg">{session.public_id}</span>
                    {session.current ? (
                      <span className="text-xs font-semibold text-accent">{currentLabel}</span>
                    ) : null}
                  </div>
                  <p className="text-xs text-fg-muted">{session.status}</p>
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
