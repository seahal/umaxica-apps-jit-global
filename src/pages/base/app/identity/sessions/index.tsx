import { router } from "@inertiajs/react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import type { IdentityLink } from "@/types/identity";

type SessionRow = {
  public_id: string;
  status: string;
  kind: string;
  binding: string;
  last_activity: string;
  created: string;
  refresh_expires: string;
  current: boolean;
  revoke_url: string;
};

type BulkRevocation = {
  others_label: string;
  others_confirm: string;
  others_url: string;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: IdentityLink;
  table_headings: {
    session: string;
    kind: string;
    binding: string;
    last_activity: string;
    created: string;
    refresh_expires: string;
  };
  current_label: string;
  revoke_label: string;
  revoke_confirm: string;
  bulk_revocation: BulkRevocation | null;
  sessions: SessionRow[];
};

export default function SessionsIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  table_headings: headings,
  current_label: currentLabel,
  revoke_label: revokeLabel,
  revoke_confirm: revokeConfirm,
  bulk_revocation: bulkRevocation,
  sessions,
}: Props) {
  const { confirm, dialog } = useConfirm();

  const revoke = (url: string, message: string, label: string) => {
    confirm({ message, confirmLabel: label }, () => router.delete(url));
  };

  return (
    <Page
      title={title}
      up={backLink}
      width="wide"
      {...(bulkRevocation === null
        ? {}
        : {
            actions: (
              <Button
                type="button"
                variant="secondary"
                size="sm"
                onPress={() =>
                  revoke(
                    bulkRevocation.others_url,
                    bulkRevocation.others_confirm,
                    bulkRevocation.others_label,
                  )
                }
              >
                {bulkRevocation.others_label}
              </Button>
            ),
          })}
    >
      {sessions.length === 0 ? (
        <p className="text-sm text-fg-muted">{emptyMessage}</p>
      ) : (
        <Table>
          <thead>
            <tr>
              <th scope="col">{headings.session}</th>
              <th scope="col">{headings.kind}</th>
              <th scope="col">{headings.binding}</th>
              <th scope="col">{headings.last_activity}</th>
              <th scope="col">{headings.created}</th>
              <th scope="col">{headings.refresh_expires}</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {sessions.map((session) => (
              <tr key={session.public_id}>
                <td>
                  <span className="font-mono break-all">{session.public_id}</span>
                  {session.current ? (
                    <span
                      className="ml-2 rounded-full bg-accent px-2 py-0.5 text-xs font-medium
                        text-accent-fg"
                    >
                      {currentLabel}
                    </span>
                  ) : null}
                  <p className="text-xs text-fg-muted">{session.status}</p>
                </td>
                <td>{session.kind}</td>
                <td>{session.binding}</td>
                <td className="whitespace-nowrap text-fg-muted">{session.last_activity}</td>
                <td className="whitespace-nowrap text-fg-muted">{session.created}</td>
                <td className="whitespace-nowrap text-fg-muted">{session.refresh_expires}</td>
                <td>
                  {session.current ? null : (
                    <Button
                      type="button"
                      variant="danger"
                      size="sm"
                      onPress={() => revoke(session.revoke_url, revokeConfirm, revokeLabel)}
                    >
                      {revokeLabel}
                    </Button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
      {dialog}
    </Page>
  );
}
