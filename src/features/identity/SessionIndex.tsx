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
  device: string;
  last_activity: string;
  created: string;
  expires_at: string;
  status: string;
  mode?: string;
  revoke: SessionAction | null;
};

export type SessionIndexProps = {
  title: string;
  back_link: { label: string; href: string };
  empty_message: string;
  expires_at_description: string;
  columns: {
    device: string;
    last_activity: string;
    created: string;
    expires_at: string;
    status: string;
    mode?: string;
    action: string;
  };
  bulk_revocations: { others: SessionAction } | null;
  sessions: SessionRow[];
};

function RevokeButton({ action }: { action: SessionAction }) {
  const { confirm, dialog } = useConfirm();
  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    const tokenField = form.elements.namedItem("authenticity_token");
    if (tokenField instanceof HTMLInputElement) {
      tokenField.value = csrfToken();
    }
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
          value=""
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
  expires_at_description: expiresAtDescription,
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
      <p className="mb-4 text-sm text-fg-muted">{expiresAtDescription}</p>

      {bulkRevocations ? (
        <div className="mb-4 flex flex-wrap gap-2">
          <RevokeButton action={bulkRevocations.others} />
        </div>
      ) : null}

      {sessions.length > 0 ? (
        <Table>
          <thead>
            <tr>
              <th scope="col">{columns.device}</th>
              {columns.mode ? <th scope="col">{columns.mode}</th> : null}
              <th scope="col">{columns.last_activity}</th>
              <th scope="col">{columns.created}</th>
              <th scope="col">{columns.expires_at}</th>
              <th scope="col">{columns.status}</th>
              <th scope="col">{columns.action}</th>
            </tr>
          </thead>
          <tbody>
            {sessions.map((session, index) => (
              <tr key={`${session.created}-${index}`}>
                <td>{session.device}</td>
                {columns.mode ? <td>{session.mode}</td> : null}
                <td>{session.last_activity}</td>
                <td>{session.created}</td>
                <td>{session.expires_at}</td>
                <td>{session.status}</td>
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
