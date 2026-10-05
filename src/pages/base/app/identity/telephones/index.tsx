import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import type { IdentityLink } from "@/types/identity";

type TelephoneRow = {
  public_id: string;
  number: string;
  status_label: string;
  edit_link: IdentityLink;
};

type Props = {
  title: string;
  empty_message: string;
  back_link: IdentityLink;
  new_link: IdentityLink;
  registration_link: IdentityLink;
  table_headings: { number: string; status: string; actions: string };
  telephones: TelephoneRow[];
};

export default function TelephonesIndex({
  title,
  empty_message: emptyMessage,
  back_link: backLink,
  new_link: newLink,
  registration_link: registrationLink,
  table_headings: headings,
  telephones,
}: Props) {
  return (
    <Page
      title={title}
      up={backLink}
      width="wide"
      actions={
        <>
          <ButtonLink
            href={newLink.href}
            size="sm"
            inertia
          >
            {newLink.label}
          </ButtonLink>
          <ButtonLink
            href={registrationLink.href}
            size="sm"
            variant="secondary"
            inertia
          >
            {registrationLink.label}
          </ButtonLink>
        </>
      }
    >
      <Table>
        <thead>
          <tr>
            <th scope="col">{headings.number}</th>
            <th scope="col">{headings.status}</th>
            <th scope="col">{headings.actions}</th>
          </tr>
        </thead>
        <tbody>
          {telephones.map((telephone) => (
            <tr key={telephone.public_id}>
              <td>{telephone.number}</td>
              <td className="text-fg-muted">{telephone.status_label}</td>
              <td>
                <TextLink href={telephone.edit_link.href}>{telephone.edit_link.label}</TextLink>
              </td>
            </tr>
          ))}
          {telephones.length === 0 ? (
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
