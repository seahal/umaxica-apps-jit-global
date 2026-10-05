// Connecting and disconnecting one social provider on the app surface.
//
// Whether the provider is linked, and whether disconnecting it would leave the account without
// another way in, are server decisions: the disconnect form is absent while the provider is
// unlinked and disabled while it is the last method, exactly as the ERB screen behaved.
//
// Connecting is a document POST rather than an Inertia visit, because the server answers it with a
// 307 into the provider's OmniAuth request phase, which the browser must follow as a navigation.
import { router } from "@inertiajs/react";
import { useState, useSyncExternalStore } from "react";

import Button from "@/components/ui/Button";
import Card from "@/components/ui/Card";
import Page from "@/components/ui/Page";
import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import { csrfToken } from "@/lib/csrf";

import type { SettingsLink, SettingsTurnstile } from "./links";

const subscribeToNothing = () => () => {};
const emptyToken = () => "";

export type SocialLinkManageProps = {
  title: string;
  heading: string;
  description: string;
  back_link: SettingsLink;
  unlink: {
    action: string;
    submit_label: string;
    allowed: boolean;
    blocked_notice: string | null;
  } | null;
  connect: { action: string; label: string } | null;
  turnstile: SettingsTurnstile | null;
};

export default function SocialLinkManage({
  heading,
  description,
  back_link: backLink,
  unlink,
  connect,
  turnstile,
}: SocialLinkManageProps) {
  const [token, setToken] = useState("");
  // The token is read on the client only, so the component renders the same markup on the server,
  // where there is no document to read the meta tag from. useSyncExternalStore gives that split
  // without a setState in an effect: the server snapshot is the empty string and the client
  // snapshot is the meta tag. The meta tag does not change within a document, so there is nothing
  // to subscribe to.
  const authenticityToken = useSyncExternalStore(subscribeToNothing, csrfToken, emptyToken);

  const disconnect = (event: React.SyntheticEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!unlink?.allowed) {
      return;
    }

    router.delete(unlink.action, { data: { "cf-turnstile-response": token } });
  };

  return (
    <Page
      title={heading}
      description={description}
      up={backLink}
      width="narrow"
    >
      <Card>
        {unlink ? (
          <div className="flex flex-col gap-2">
            <form
              onSubmit={disconnect}
              className="flex flex-col gap-2"
            >
              {turnstile ? (
                <TurnstileWidget
                  site_key={turnstile.site_key}
                  mode={turnstile.mode}
                  action={turnstile.action}
                  cdata={turnstile.cdata}
                  onToken={setToken}
                />
              ) : null}
              <div>
                <Button
                  type="submit"
                  variant="danger"
                  isDisabled={!unlink.allowed}
                >
                  {unlink.submit_label}
                </Button>
              </div>
            </form>
            {unlink.blocked_notice ? (
              <p className="text-base text-fg-muted">{unlink.blocked_notice}</p>
            ) : null}
          </div>
        ) : null}

        {connect ? (
          <form
            method="post"
            action={connect.action}
          >
            <input
              type="hidden"
              name="authenticity_token"
              value={authenticityToken}
            />
            <Button type="submit">{connect.label}</Button>
          </form>
        ) : null}
      </Card>
    </Page>
  );
}
