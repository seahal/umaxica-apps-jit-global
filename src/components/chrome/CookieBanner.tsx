// React port of the `cookie-banner` Stimulus controller.
//
// The consent decision itself stays on the server: this component only reports a choice to
// /web/v0/cookie and reflects what the server answers. It never writes the consent cookie itself,
// because the verified preference JWT is minted server-side.
import { useEffect, useRef, useState } from "react";

import Button from "@/components/ui/Button";
import ButtonLink from "@/components/ui/ButtonLink";
import { hasRecordedCookieConsent } from "@/lib/cookies";
import { readBoolean } from "@/lib/payload";
import { csrfToken, preferenceQueryParameters } from "@/lib/request";
import type { ChromeCookieControls } from "@/types/inertia";

function cookieEndpointUrl(): string {
  const endpoint = new URL("/web/v0/cookie", window.location.origin);
  for (const [key, value] of preferenceQueryParameters()) {
    endpoint.searchParams.set(key, value);
  }
  return endpoint.toString();
}

export default function CookieBanner({ controls }: { controls: ChromeCookieControls }) {
  if (controls.hidden) {
    return null;
  }

  return <CookieBannerPrompt controls={controls} />;
}

function CookieBannerPrompt({ controls }: { controls: ChromeCookieControls }) {
  // Nothing is painted until something says the visitor has not answered. The consent buffer
  // cookie is a projection of the same decision the endpoint below reports, and reading it through
  // the Cookie Store API is asynchronous, so it can no longer seed the first render - starting
  // hidden is what keeps a visitor who already answered from seeing the banner flash on every
  // load, which is the flash that projection exists to prevent.
  const [visible, setVisible] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  // An answer given before the read returns wins, the same way a theme choice does: the visitor is
  // more current than the in-flight request, and re-raising a banner they just dismissed is worse
  // than showing a stale one.
  const answered = useRef(false);
  // The endpoint is the authority, so once it has answered the cookie must not speak again. The
  // two reads race - one local, one over the network - and without this a slow cookie read could
  // raise a banner the server had already said to hide.
  const reconciled = useRef(false);

  useEffect(() => {
    let active = true;

    // The projection only ever raises the banner. It cannot hide one, because a cookie recording
    // consent is not itself proof the server still agrees; that is what the endpoint answers.
    const readConsentBuffer = async () => {
      const recorded = await hasRecordedCookieConsent();

      if (active && !answered.current && !reconciled.current && !recorded) {
        setVisible(true);
      }
    };

    const readConsent = async () => {
      try {
        const response = await fetch(cookieEndpointUrl());
        if (!response.ok) {
          return;
        }
        const state: unknown = await response.json();
        if (active && !answered.current) {
          reconciled.current = true;
          // `show_banner` is the field the endpoint answers with
          // (`PreferenceWebCookieActions#show`). Reading `consented` here - a key that response
          // has never carried - is why a recorded decision never suppressed the banner: the read
          // silently found nothing and left it up on every load.
          //
          // Anything other than an explicit `false` leaves the banner visible, because a consent
          // prompt that fails to appear is the worse of the two failures.
          setVisible(readBoolean(state, "show_banner") !== false);
        }
      } catch {
        // Keep the banner visible when the verified preference JWT cannot be read.
      }
    };

    void readConsentBuffer();
    void readConsent();

    return () => {
      active = false;
    };
  }, []);

  if (!visible) {
    return null;
  }

  const submitConsent = async (consented: boolean) => {
    setSubmitting(true);
    try {
      const response = await fetch(cookieEndpointUrl(), {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({
          // Recording a decision is itself consent to store it, so `consented` is true for both
          // answers; the category flags carry the actual choice.
          cookie: {
            consented: true,
            functional: consented,
            performant: consented,
            targetable: consented,
          },
        }),
      });

      if (response.ok) {
        answered.current = true;
        setVisible(false);
      }
    } finally {
      setSubmitting(false);
    }
  };

  return (
    // A landmark, not a dialog. It previously declared `role="dialog"` while providing none of
    // what that role promises — no `aria-modal`, no focus trap, no Escape, and nothing stopping
    // the page behind it being read. Announcing a dialog and then behaving like a banner is worse
    // than announcing nothing, because it tells assistive technology the rest of the page is
    // unavailable when it is not. A labelled `<section>` describes what this actually is: a
    // persistent region the actor can reach, ignore, or dismiss.
    <section
      id="cookie-banner"
      aria-labelledby="cookie-title"
      className="fixed inset-x-0 bottom-0 z-50 border-t border-line bg-surface shadow-lg"
    >
      <div className="relative mx-auto flex max-w-4xl flex-col gap-3 p-4">
        <Button
          variant="ghost"
          size="sm"
          onPress={() => {
            answered.current = true;
            setVisible(false);
          }}
          aria-label={controls.close_button}
          className="absolute top-2 right-2 rounded-full p-2"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="size-4"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <line
              x1="18"
              y1="6"
              x2="6"
              y2="18"
            />
            <line
              x1="6"
              y1="6"
              x2="18"
              y2="18"
            />
          </svg>
        </Button>

        <h2
          id="cookie-title"
          className="pr-8 text-sm font-semibold text-fg"
        >
          {controls.title}
        </h2>

        <p className="text-sm text-fg-muted">{controls.description_html}</p>

        <div className="flex flex-wrap gap-2">
          <Button
            variant="secondary"
            size="sm"
            isDisabled={submitting}
            onPress={() => void submitConsent(false)}
          >
            {controls.reject_all}
          </Button>

          <ButtonLink
            variant="secondary"
            size="sm"
            href={controls.settings_url}
          >
            {controls.open_settings}
          </ButtonLink>

          <Button
            size="sm"
            isDisabled={submitting}
            onPress={() => void submitConsent(true)}
          >
            {controls.accept_all}
          </Button>
        </div>
      </div>
    </section>
  );
}
