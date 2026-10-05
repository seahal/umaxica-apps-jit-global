// Connecting the operator's Microsoft Entra ID identity.
//
// The connect button is a document POST to the settings endpoint, which redirects into the Entra
// ceremony, so it stays a native form rather than an Inertia visit. Whether connecting may be
// offered at all is a server decision: a connected identity, or an unavailable provider, arrives
// with a notice and no form. There is nothing to choose here — the org surface federates a single
// Entra tenant configured server-side.
import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import { csrfToken } from "@/lib/csrf";

export type OrgEntraSettingsEditProps = {
  title: string;
  heading: string;
  back_link: { label: string; href: string };
  connected: boolean;
  connected_notice: string | null;
  unavailable_notice: string | null;
  form: { action: string; submit_label: string } | null;
};

export default function OrgEntraSettingsEdit({
  heading,
  back_link: backLink,
  connected,
  connected_notice: connectedNotice,
  unavailable_notice: unavailableNotice,
  form,
}: OrgEntraSettingsEditProps) {
  return (
    <Page
      title={heading}
      up={backLink}
      width="narrow"
    >
      <Card>
        {connected ? (
          <div className="flex flex-col gap-1 text-base">
            <p className="font-medium text-fg">Connected</p>
            {connectedNotice ? <p className="text-fg-muted">{connectedNotice}</p> : null}
          </div>
        ) : null}

        {form ? (
          <form
            action={form.action}
            method="post"
          >
            <input
              type="hidden"
              name="authenticity_token"
              value={csrfToken()}
              readOnly
            />
            <Button type="submit">{form.submit_label}</Button>
          </form>
        ) : null}

        {unavailableNotice ? <p className="text-base text-fg-muted">{unavailableNotice}</p> : null}
      </Card>
    </Page>
  );
}
