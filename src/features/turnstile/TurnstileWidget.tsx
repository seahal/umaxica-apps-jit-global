// React port of the `turnstile` Stimulus controller.
//
// The widget renders the Cloudflare challenge and writes its token into a hidden field that the
// form submits, exactly as the ERB partial did. The token is never trusted here: the server
// validates it, and a challenge that cannot be presented leaves the field empty so the server
// rejects the submission rather than the client deciding it passed.
import { useEffect, useRef, useState } from "react";

import { waitForTurnstileApi, type TurnstileApi } from "@/lib/turnstile";

export type TurnstileWidgetProps = {
  /** Site key, published by the server; the secret half never reaches the browser. */
  site_key: string;
  /** Server-generated render identity used by pages that must force a fresh challenge. */
  challenge_id?: string | null;
  action?: string | null;
  cdata?: string | null;
  /** "execute" runs the challenge immediately; "render" shows the widget and waits. */
  mode?: "render" | "execute";
  error_message?: string;
  /** Called with the token, or with an empty string when the challenge is no longer valid. */
  onToken?: (token: string) => void;
};

const DEFAULT_ERROR_MESSAGE = "Security verification failed. Please refresh and try again.";

export default function TurnstileWidget({
  site_key: siteKey,
  action,
  cdata,
  mode = "render",
  error_message: errorMessage = DEFAULT_ERROR_MESSAGE,
  onToken,
}: TurnstileWidgetProps) {
  const container = useRef<HTMLDivElement>(null);
  const [token, setToken] = useState("");
  const [failure, setFailure] = useState<string | null>(null);

  useEffect(() => {
    let removed = false;
    let widgetId: string | null = null;
    let api: TurnstileApi | null = null;

    const publish = (value: string) => {
      setToken(value);
      onToken?.(value);
    };

    const start = async () => {
      const element = container.current;
      /* v8 ignore next -- the effect runs after the host div is committed */
      if (!element) {
        return;
      }

      try {
        api = await waitForTurnstileApi(errorMessage);
      } catch {
        if (!removed) {
          setFailure(errorMessage);
        }
        return;
      }

      if (removed) {
        return;
      }

      widgetId = api.render(element, {
        sitekey: siteKey,
        ...(action ? { action } : {}),
        ...(cdata ? { cData: cdata } : {}),
        callback: (value: string) => publish(value),
        "error-callback": () => {
          publish("");
          return true;
        },
        "expired-callback": () => publish(""),
        "timeout-callback": () => publish(""),
        "unsupported-callback": () => publish(""),
      });

      if (mode === "execute") {
        api.execute(widgetId);
      }
    };

    void start();

    return () => {
      removed = true;
      if (api && widgetId) {
        api.remove(widgetId);
      }
    };
    // The challenge is rendered once per mount; its configuration comes from the server and does
    // not change while the page is open.
    // oxlint-disable-next-line exhaustive-deps, react/exhaustive-effect-dependencies
  }, []);

  return (
    <div className="flex flex-col gap-2">
      <div
        ref={container}
        className="cf-turnstile"
      />
      <input
        type="hidden"
        name="cf-turnstile-response"
        autoComplete="off"
        value={token}
        readOnly
      />
      {failure ? (
        <p
          role="alert"
          className="text-sm text-danger"
        >
          {failure}
        </p>
      ) : null}
    </div>
  );
}
