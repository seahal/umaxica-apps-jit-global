import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/emails/index.html.erb`. The verified/unverified wording is
// resolved on the server, so the status column is finished text rather than a status id.

export type EmailRow = {
  public_id: string;
  address: string;
  status_label: string;
  edit_link: PageLink;
};

export type EmailsIndexProps = {
  title: string;
  back_link: PageLink;
  new_link: PageLink;
  columns: { address: string; status: string; actions: string };
  empty_message: string;
  emails: EmailRow[];
};

export default function EmailsIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  emails,
}: EmailsIndexProps) {
  return (
    <Page
      title={title}
      up={backLink}
      upVisit="inertia"
      width="wide"
      actions={
        <ButtonLink
          href={newLink.href}
          inertia
        >
          {newLink.label}
        </ButtonLink>
      }
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.address}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {emails.map((email) => (
            <tr
              key={email.public_id}
              className="last:border-0"
            >
              <td>{email.address}</td>
              <td>
                <span>{email.status_label}</span>
              </td>
              <td>
                <TextLink
                  href={email.edit_link.href}
                  inertia
                  tone="muted"
                >
                  {email.edit_link.label}
                </TextLink>
              </td>
            </tr>
          ))}
          {emails.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="py-6 text-center"
              >
                <p className="text-base text-fg-muted">{emptyMessage}</p>
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
