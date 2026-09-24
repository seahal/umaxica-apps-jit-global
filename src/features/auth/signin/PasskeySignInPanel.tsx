// React passkey sign-in panel for the app/com sign-in pages.
//
// The ceremony is unchanged: solve an invisible Turnstile token, POST it to the anonymous options
// endpoint, run `navigator.credentials.get`, POST the assertion to the verification
// endpoint, and follow the redirect the server returns. Both endpoints are the same routes with the
// same rate limits and the same CSRF header; the current panel keeps the ceremony discoverable and
// does not collect or submit an account identifier. The status and error strings remain literals
// rather than becoming new translation keys.
import { useRef } from "react";

import Button from "@/components/ui/Button";
import {
  PASSKEY_MESSAGES,
  TURNSTILE_DEFAULT_ERROR,
  authenticationErrorMessage,
} from "@/features/auth/passkeys/messages";
import { useCeremonyMessages } from "@/features/auth/passkeys/useCeremonyMessages";
import { getAssertion, passkeysSupported } from "@/features/auth/passkeys/webauthn";
import { solveInvisibleTurnstile } from "@/features/auth/turnstile/invisibleToken";
import { readNonEmptyString, readObject, readString } from "@/lib/payload";

import { csrfToken } from "./csrf";

export type PasskeySignInPanelProps = {
  options_url: string;
  verification_url: string;
  region: string;
  identifier_param: string | null;
  /** Public site key; the secret half and the token verification stay server side. */
  turnstile_site_key: string;
  turnstile_error_message: string;
  field: { label: string; placeholder: string } | null;
  submit_label: string;
};

async function postJson(url: string, body: unknown): Promise<Response> {
  return fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    body: JSON.stringify(body),
  });
}

/** Reproduces the controller's failure branches, including the reload on 401/302. */
async function readFailure(response: Response, fallback: string): Promise<Error | null> {
  /* v8 ignore next -- fetch always supplies a Headers object */
  const contentType = response.headers.get("content-type") ?? "";
  if (contentType.includes("application/json")) {
    const data: unknown = await response.json();
    return new Error(readNonEmptyString(data, "error") ?? fallback);
  }
  if (response.status === 401 || response.status === 302) {
    window.location.reload();
    return null;
  }
  return new Error(fallback);
}

export default function PasskeySignInPanel({
  options_url: optionsUrl,
  verification_url: verificationUrl,
  region,
  identifier_param: identifierParam,
  turnstile_site_key: turnstileSiteKey,
  turnstile_error_message: turnstileErrorMessage,
  submit_label: submitLabel,
}: PasskeySignInPanelProps) {
  const host = useRef<HTMLDivElement>(null);
  const { error, status, showError, showStatus, clearMessages } = useCeremonyMessages();

  const authenticate = async () => {
    clearMessages();

    if (!passkeysSupported()) {
      showError(PASSKEY_MESSAGES.unsupported);
      return;
    }

    try {
      const token = await solveInvisibleTurnstile(
        turnstileSiteKey,
        turnstileErrorMessage || TURNSTILE_DEFAULT_ERROR,
        host.current,
      );

      showStatus(PASSKEY_MESSAGES.fetchingOptions);
      const optionsResponse = await postJson(optionsUrl, {
        ...(identifierParam === null ? {} : { [identifierParam]: "" }),
        "cf-turnstile-response": token,
        ri: region || undefined,
      });

      if (!optionsResponse.ok) {
        const failure = await readFailure(optionsResponse, PASSKEY_MESSAGES.optionsFailed);
        if (!failure) {
          return;
        }
        throw failure;
      }

      const optionsPayload: unknown = await optionsResponse.json();
      const challengeId = readString(optionsPayload, "challenge_id");
      const options = readObject(optionsPayload, "options");
      if (!challengeId || options === undefined) {
        throw new Error(PASSKEY_MESSAGES.optionsFailed);
      }

      showStatus(PASSKEY_MESSAGES.confirming);
      const credential = await getAssertion(options);

      showStatus(PASSKEY_MESSAGES.verifying);
      const verificationResponse = await postJson(verificationUrl, {
        challenge_id: challengeId,
        credential,
        ri: region || undefined,
      });

      if (!verificationResponse.ok) {
        const failure = await readFailure(
          verificationResponse,
          PASSKEY_MESSAGES.verificationFailed,
        );
        if (!failure) {
          return;
        }
        throw failure;
      }

      const result: unknown = await verificationResponse.json();
      const outcome = readString(result, "status");
      const redirectUrl = readString(result, "redirect_url");

      if (outcome === "totp_required" && redirectUrl) {
        showStatus(PASSKEY_MESSAGES.totpRequired);
        window.location.href = redirectUrl;
      } else if (outcome === "ok" && redirectUrl) {
        showStatus(PASSKEY_MESSAGES.loginComplete);
        window.location.href = redirectUrl;
      } else {
        throw new Error(PASSKEY_MESSAGES.unexpectedResponse);
      }
    } catch (caught) {
      showError(authenticationErrorMessage(caught));
    }
  };

  return (
    <div
      ref={host}
      className="flex flex-col gap-4"
    >
      {error ? (
        <p
          role="alert"
          className="text-sm text-danger"
        >
          {error}
        </p>
      ) : null}
      {status ? <p className="text-sm text-fg-muted">{status}</p> : null}

      <div>
        <Button
          type="button"
          onPress={() => void authenticate()}
        >
          {submitLabel}
        </Button>
      </div>
    </div>
  );
}
