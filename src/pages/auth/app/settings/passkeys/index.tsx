// The passkeys registered on an app account.
//
// Each row is serialized by the server: a public id, the description its owner gave it, formatted
// timestamps and the URLs of the actions this actor may take. Deleting one carries an invisible
// Turnstile token, which only the server decides the worth of.
import { router } from "@inertiajs/react";
import { useState } from "react";

import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import type { SettingsLink, SettingsTurnstile } from "@/features/auth/settings/links";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";

type PasskeyRow = {
  public_id: string;
  description: string | null;
  created_at: string;
  last_used_at: string;
  edit_href: string;
  destroy_href: string;
};

type Props = {
  title: string;
  back_link: SettingsLink;
  new_link: SettingsLink;
  columns: {
    description: string;
    created_at: string;
    last_used_at: string;
    actions: string;
  };
  empty_message: string;
  edit_label: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: SettingsTurnstile;
  passkeys: PasskeyRow[];
};

export default function PasskeysIndex({
  title,
  back_link: backLink,
  new_link: newLink,
  columns,
  empty_message: emptyMessage,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
  passkeys,
}: Props) {
  const [token, setToken] = useState("");
  const { confirm, dialog } = useConfirm();

  const destroy = (href: string) => {
    confirm({ message: destroyConfirm, confirmLabel: destroyLabel }, () => {
      router.delete(href, { data: { "cf-turnstile-response": token } });
    });
  };

  return (
    <Page
      title={title}
      up={backLink}
      width="wide"
      actions={
        <ButtonLink
          href={newLink.href}
          size="sm"
        >
          {newLink.label}
        </ButtonLink>
      }
    >
      <TurnstileWidget
        site_key={turnstile.site_key}
        mode={turnstile.mode}
        action={turnstile.action}
        cdata={turnstile.cdata}
        onToken={setToken}
      />

      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.description}</th>
            <th scope="col">{columns.created_at}</th>
            <th scope="col">{columns.last_used_at}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {passkeys.map((passkey) => (
            <tr key={passkey.public_id}>
              <td>{passkey.description}</td>
              <td className="whitespace-nowrap text-fg-muted">{passkey.created_at}</td>
              <td className="whitespace-nowrap text-fg-muted">{passkey.last_used_at}</td>
              <td>
                <div className="flex flex-wrap items-center gap-3">
                  <TextLink href={passkey.edit_href}>{editLabel}</TextLink>
                  <Button
                    type="button"
                    variant="danger"
                    size="sm"
                    onPress={() => destroy(passkey.destroy_href)}
                  >
                    {destroyLabel}
                  </Button>
                </div>
              </td>
            </tr>
          ))}
          {passkeys.length === 0 ? (
            <tr>
              <td
                colSpan={4}
                className="text-fg-muted italic"
              >
                {emptyMessage}
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
      {dialog}
    </Page>
  );
}
