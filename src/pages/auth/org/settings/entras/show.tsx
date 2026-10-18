// The read-only view of the operator's Microsoft Entra ID connection state.
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

type EntraLink = {
  label: string;
  href: string;
};

export type OrgEntraSettingsShowProps = {
  title: string;
  heading: string;
  back_link: EntraLink;
  status: string;
  edit_link: EntraLink;
};

export default function OrgEntraSettingsShow({
  heading,
  back_link: backLink,
  status,
  edit_link: editLink,
}: OrgEntraSettingsShowProps) {
  return (
    <Page
      title={heading}
      up={backLink}
      width="narrow"
    >
      <Card>
        <p className="text-base text-fg">{status}</p>
        <p className="text-base">
          <TextLink href={editLink.href}>{editLink.label}</TextLink>
        </p>
      </Card>
    </Page>
  );
}
