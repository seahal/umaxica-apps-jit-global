// One registered passkey in detail.
//
// The rows are built on the server, so the formatting, the translation and the "unknown
// authenticator" fallback stay in one place. This screen reads; renaming and removal live behind
// the edit link.
import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import type { SettingsLink } from "@/features/auth/settings/links";

type Props = {
  title: string;
  description: string;
  back_link: SettingsLink;
  passkey_description: string | null;
  details: { key: string; label: string; value: string }[];
  edit_link: SettingsLink;
};

export default function PasskeysShow({
  title,
  description,
  back_link: backLink,
  passkey_description: passkeyDescription,
  details,
  edit_link: editLink,
}: Props) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="narrow"
    >
      <Card {...(passkeyDescription === null ? {} : { heading: passkeyDescription })}>
        <DescriptionList
          items={details.map((detail) => ({ term: detail.label, description: detail.value }))}
        />
      </Card>

      <p className="text-base">
        <TextLink href={editLink.href}>{editLink.label}</TextLink>
      </p>
    </Page>
  );
}
