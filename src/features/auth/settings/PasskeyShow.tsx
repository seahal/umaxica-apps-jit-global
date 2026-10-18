import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
// One registered passkey in detail.
//
// The rows are built on the server so the formatting, the translation and the "unknown
// authenticator" fallback stay in one place.
import PasskeyDeleteButton, {
  type TurnstileConfiguration,
} from "@/features/auth/settings/PasskeyDeleteButton";

export type PasskeyDetail = {
  key: string;
  label: string;
  value: string;
};

export type PasskeyShowProps = {
  title: string;
  back_link: { label: string; href: string };
  details: PasskeyDetail[];
  edit_link: { label: string; href: string };
  destroy_href: string;
  destroy_label: string;
  confirm_message: string;
  turnstile: TurnstileConfiguration;
};

export default function PasskeyShow({
  title,
  back_link: backLink,
  details,
  edit_link: editLink,
  destroy_href: destroyHref,
  destroy_label: destroyLabel,
  confirm_message: confirmMessage,
  turnstile,
}: PasskeyShowProps) {
  return (
    <Page
      title={title}
      up={backLink}
      width="narrow"
    >
      <Card>
        <DescriptionList
          items={details.map((detail) => ({ term: detail.label, description: detail.value }))}
        />

        <div className="flex flex-wrap items-center gap-4">
          <TextLink
            href={editLink.href}
            tone="muted"
            className="text-base"
          >
            {editLink.label}
          </TextLink>
          <PasskeyDeleteButton
            action={destroyHref}
            label={destroyLabel}
            confirm_message={confirmMessage}
            turnstile={turnstile}
          />
        </div>
      </Card>
    </Page>
  );
}
