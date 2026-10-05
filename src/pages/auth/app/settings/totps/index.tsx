// The authenticator apps registered on an app account.
//
// Every cell arrives formatted from the server, including the placeholder a credential that has
// never produced a code shows.
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import type { SettingsLink } from "@/features/auth/settings/links";

type TotpRow = {
  public_id: string;
  title: string | null;
  last_otp_at: string;
  status: string;
  edit_href: string;
};

type Props = {
  title: string;
  back_link: SettingsLink;
  new_link: SettingsLink;
  columns: { title: string; last_otp_at: string; status: string; actions: string };
  empty_message: string;
  edit_label: string;
  totps: TotpRow[];
};

export default function TotpsIndex({
  title,
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
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {totps.map((totp) => (
            <tr key={totp.public_id}>
              <td>{totp.title}</td>
              <td>{totp.last_otp_at}</td>
              <td>{totp.status}</td>
              <td>
                <TextLink href={totp.edit_href}>{editLabel}</TextLink>
              </td>
            </tr>
          ))}
          {totps.length === 0 ? (
            <tr>
              <td colSpan={4}>
                <p>{emptyMessage}</p>
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
