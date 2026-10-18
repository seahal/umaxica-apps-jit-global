import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

// The read-only link status of one social provider on the app surface.
//
// Apple and Google render the same screen, so the copy, the status sentence and every URL arrive
// already resolved from the server and the component only lays them out.
import type { SettingsLink } from "./links";

export type SocialLinkStatusProps = {
  title: string;
  heading: string;
  description: string;
  status: string;
  back_link: SettingsLink;
  edit_link: SettingsLink;
};

export default function SocialLinkStatus({
  heading,
  description,
  status,
  back_link: backLink,
  edit_link: editLink,
}: SocialLinkStatusProps) {
  return (
    <Page
      title={heading}
      description={description}
      up={backLink}
      width="narrow"
    >
      <Card>
        <p className="text-base text-fg">{status}</p>
        <p className="text-base">
          <TextLink
            href={editLink.href}
            tone="muted"
          >
            {editLink.label}
          </TextLink>
        </p>
      </Card>
    </Page>
  );
}
