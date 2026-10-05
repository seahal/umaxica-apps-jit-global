// The operator's registered passkeys.
//
// Deletion stays a document DELETE form: it carries a stealth Turnstile token in the same
// `cf-turnstile-response` field the server already verifies, so the request shape is unchanged.
import { useConfirm } from "@/components/ConfirmDialog";
import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import Table from "@/components/ui/Table";
import TextLink from "@/components/ui/TextLink";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

type PasskeyRow = {
  description: string;
  created_at: string;
  edit_href: string;
  destroy_action: string;
};

type TurnstileConfiguration = {
  site_key: string;
  mode: "render" | "execute";
  action: string | null;
  cdata: string | null;
};

export type OrgPasskeySettingsIndexProps = {
  title: string;
  description: string;
  add_link: { label: string; href: string };
  back_link: { label: string; href: string };
  columns: { description: string; created_at: string; actions: string };
  empty: string;
  edit_label: string;
  destroy_label: string;
  destroy_confirm: string;
  turnstile: TurnstileConfiguration;
  passkeys: PasskeyRow[];
};

function DestroyForm({
  action,
  label,
  message,
  turnstile,
}: {
  action: string;
  label: string;
  message: string;
  turnstile: TurnstileConfiguration;
}) {
  const { confirm, dialog } = useConfirm();

  // The submission is held back until the operator accepts, then replayed with `submit()`, which
  // sends the same document DELETE without running this handler again.
  const submit = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    confirm({ message, confirmLabel: label }, () => form.submit());
  };

  return (
    <>
      <form
        action={action}
        method="post"
        onSubmit={submit}
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
          {label}
        </Button>
      </form>
      {dialog}
    </>
  );
}

export default function OrgPasskeySettingsIndex({
  title,
  description,
  add_link: addLink,
  back_link: backLink,
  columns,
  empty,
  edit_label: editLabel,
  destroy_label: destroyLabel,
  destroy_confirm: destroyConfirm,
  turnstile,
  passkeys,
}: OrgPasskeySettingsIndexProps) {
  return (
    <Page
      title={title}
      description={description}
      up={backLink}
      width="wide"
      actions={
        <a
          href={addLink.href}
          className="inline-flex items-center justify-center rounded-md bg-accent px-4 py-2
            text-base font-medium text-accent-fg hover:bg-accent-hover"
        >
          {addLink.label}
        </a>
      }
    >
      <Table label={title}>
        <thead>
          <tr>
            <th scope="col">{columns.description}</th>
            <th scope="col">{columns.created_at}</th>
            <th scope="col">
              <span>{columns.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody>
          {passkeys.map((passkey) => (
            <tr key={passkey.destroy_action}>
              <td>{passkey.description}</td>
              <td className="whitespace-nowrap text-fg-muted">{passkey.created_at}</td>
              <td>
                <div className="flex flex-wrap items-center gap-3">
                  <TextLink href={passkey.edit_href}>{editLabel}</TextLink>
                  <DestroyForm
                    action={passkey.destroy_action}
                    label={destroyLabel}
                    message={destroyConfirm}
                    turnstile={turnstile}
                  />
                </div>
              </td>
            </tr>
          ))}
          {passkeys.length === 0 ? (
            <tr>
              <td
                colSpan={3}
                className="text-fg-muted italic"
              >
                {empty}
              </td>
            </tr>
          ) : null}
        </tbody>
      </Table>
    </Page>
  );
}
