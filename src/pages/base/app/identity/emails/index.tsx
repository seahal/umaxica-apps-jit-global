import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink } from "@/types/identity";

type EmailRow = {
  public_id: string;
  address: string;
  status_label: string;
  edit_link: IdentityLink;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: IdentityLink;
  new_link: IdentityLink;
  table_headings: { address: string; status: string; actions: string };
  emails: EmailRow[];
};

export default function EmailsIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  new_link: newLink,
  table_headings: headings,
  emails,
}: Props) {
  return (
    <Page
      title={title}
      up={backLink}
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
            <th scope="col">{headings.address}</th>
            <th scope="col">{headings.status}</th>
            <th scope="col">{headings.actions}</th>
          </tr>
        </thead>
        <tbody>
          {emails.map((email) => (
            <tr key={email.public_id}>
              <td>{email.address}</td>
              <td className="text-fg-muted">{email.status_label}</td>
              <td>
                <TextLink href={email.edit_link.href}>{email.edit_link.label}</TextLink>
              </td>
            </tr>
          ))}
          {emails.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="text-fg-muted italic"
              >
                {emptyMessage}
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
