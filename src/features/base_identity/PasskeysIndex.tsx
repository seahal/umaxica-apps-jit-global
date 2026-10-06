import { router } from "@inertiajs/react";
import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import TextLink from "@/components/ui/TextLink";

type Row = {
  public_id: string;
  description: string;
  created_at: string | null;
  last_used_at: string | null;
  show_href: string;
  destroy_action: string;
};

type Props = {
  title: string;
  description: string;
  back_link: { label: string; href: string };
  new_link: { label: string; href: string };
  remove_label: string;
  remove_confirm: string;
  empty_message: string;
  passkeys: Row[];
};

export default function PasskeysIndex({
  title,
  description,
  back_link: backLink,
  new_link: newLink,
  remove_label: removeLabel,
  remove_confirm: removeConfirm,
  empty_message: emptyMessage,
  passkeys,
}: Props) {
  const { confirm, dialog } = useConfirm();

  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
      actions={<ButtonLink href={newLink.href}>{newLink.label}</ButtonLink>}
    >
      <ul className="flex flex-col gap-4">
        {passkeys.map((passkey) => (
          <li
            key={passkey.public_id}
            className="flex items-center justify-between gap-4"
          >
            <TextLink href={passkey.show_href}>{passkey.description}</TextLink>
            <Button
              type="button"
              variant="danger"
              onPress={() =>
                confirm({ message: removeConfirm, confirmLabel: removeLabel }, () =>
                  router.delete(passkey.destroy_action),
                )
              }
            >
              {removeLabel}
            </Button>
          </li>
        ))}
        {passkeys.length === 0 ? <li>{emptyMessage}</li> : null}
      </ul>
      {dialog}
    </Page>
  );
}
