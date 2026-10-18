// The identifier list of a self-service identity screen (email addresses, telephone numbers).
//
// Column headings, the verification wording and every destination arrive resolved from the server,
// so the table renders the payload without deciding anything about it.
import { Link } from "@inertiajs/react";

import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

export type CredentialEntry = {
  public_id: string;
  value: string;
  status: string;
  edit_link: { label: string; href: string };
};

export type CredentialIndexProps = {
  title: string;
  back_link: { label: string; href: string };
  new_link: { label: string; href: string };
  columns: { value: string; status: string; actions: string };
  empty_message: string;
  entries: CredentialEntry[];
};

export default function CredentialIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  entries,
}: CredentialIndexProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
      width="wide"
      actions={
        <ButtonLink
          href={newLink.href}
          size="sm"
          inertia
        >
          {newLink.label}
        </ButtonLink>
      }
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.value}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">{columns.actions}</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr key={entry.public_id}>
              <td>{entry.value}</td>
              <td>
                <span className="text-fg-muted">{entry.status}</span>
              </td>
              <td>
                <Link
                  href={entry.edit_link.href}
                  className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg hover:underline"
                >
                  {entry.edit_link.label}
                </Link>
              </td>
            </tr>
          ))}
          {entries.length === 0 ? (
            <tr>
              <td colSpan={3}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
