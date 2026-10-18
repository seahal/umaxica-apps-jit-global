import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import type { PageLink } from "@/features/base_com/identity/types";

// Replaces `app/views/base/com/identity/telephones/index.html.erb`.

export type TelephoneRow = {
  public_id: string;
  number: string;
  status_label: string;
  edit_link: PageLink;
};

export type TelephonesIndexProps = {
  title: string;
  back_link: PageLink;
  new_link: PageLink;
  columns: { number: string; status: string; actions: string };
  empty_message: string;
  telephones: TelephoneRow[];
};

export default function TelephonesIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  telephones,
}: TelephonesIndexProps) {
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
            <th scope="col">{columns.number}</th>
            <th scope="col">{columns.status}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {telephones.map((telephone) => (
            <tr
              key={telephone.public_id}
              className="last:border-0"
            >
              <td>{telephone.number}</td>
              <td>
                <span>{telephone.status_label}</span>
              </td>
              <td>
                <TextLink
                  href={telephone.edit_link.href}
                  inertia
                  tone="muted"
                >
                  {telephone.edit_link.label}
                </TextLink>
              </td>
            </tr>
          ))}
          {telephones.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="py-6 text-center"
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
