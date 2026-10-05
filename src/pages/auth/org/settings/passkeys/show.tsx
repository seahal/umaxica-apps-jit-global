// One registered passkey, with the same DELETE form the index row carries.
import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import DescriptionList from "@/components/ui/DescriptionList";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgPasskeySettingsShowProps = {
  title: string;
  back_link: { label: string; href: string };
  details: { term: string; value: string }[];
  edit_link: { label: string; href: string };
  destroy_action: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: TurnstileConfiguration;
};

export default function OrgPasskeySettingsShow({
  title,
  back_link: backLink,
  details,
  edit_link: editLink,
  destroy_action: destroyAction,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
}: OrgPasskeySettingsShowProps) {
  const { confirm, dialog } = useConfirm();

  // The submission is held back until the actor accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm({ message: destroyConfirm, confirmLabel: destroyLabel }, () => form.submit());
  };

  return (
    <Page
      title={title}
      up={backLink}
      width="narrow"
    >
      <Card>
        <DescriptionList
          items={details.map((detail) => ({ term: detail.term, description: detail.value }))}
        />

        <div className="flex flex-wrap items-center gap-4">
          <TextLink
            href={editLink.href}
            tone="muted"
            className="text-base"
          >
            {editLink.label}
          </TextLink>

          <form
            action={destroyAction}
            method="post"
            onSubmit={submit}
            className="flex flex-col gap-2"
          >
            <input
              type="hidden"
              name="_method"
              value="delete"
              readOnly
            />
            <input
              type="hidden"
              name="authenticity_token"
              value={csrfToken()}
              readOnly
            />
            <TurnstileWidget
              site_key={turnstile.site_key}
              mode={turnstile.mode}
              action={turnstile.action}
              cdata={turnstile.cdata}
            />
            <Button
              type="submit"
              variant="danger"
              size="sm"
            >
              {destroyLabel}
            </Button>
          </form>
        </div>
      </Card>
      {dialog}
    </Page>
  );
}
