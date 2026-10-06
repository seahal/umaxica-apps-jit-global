import { Link } from "@inertiajs/react";

import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";

type TotpRow = {
  public_id: string;
  title: string;
  last_otp_at: string;
  status: string;
  show_href: string;
};

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  new_link: { label: string; href: string };
  columns: { title: string; last_otp_at: string; status: string; actions: string };
  empty_message: string;
  edit_label: string;
  totps: TotpRow[];
};

export default function TotpsIndex({
  title,
  description,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  edit_label: editLabel,
  totps,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
      actions={<ButtonLink href={newLink.href}>{newLink.label}</ButtonLink>}
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.title}</th>
            <th scope="col">{columns.last_otp_at}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">{columns.actions}</th>
          </tr>
        </thead>
        <tbody>
          {totps.map((totp) => (
            <tr key={totp.public_id}>
              <td>{totp.title}</td>
              <td>{totp.last_otp_at}</td>
              <td>{totp.status}</td>
              <td>
                <Link
                  href={totp.show_href}
                  className="ui-text-link text-base text-fg-muted underline underline-offset-4 hover:text-fg"
                >
                  {editLabel}
                </Link>
              </td>
            </tr>
          ))}
          {totps.length === 0 ? (
            <tr>
              <td colSpan={4}>{emptyMessage}</td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
