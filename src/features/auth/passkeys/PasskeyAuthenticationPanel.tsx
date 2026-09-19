// React port of `src/controllers/passkey_authentication_controller.js`.
//
// The ceremony is unchanged: solve an invisible Turnstile token, POST it with the identifier to the
// options endpoint, run `navigator.credentials.get`, POST the assertion to the verification
// endpoint, and follow the redirect the server returns. Both endpoints are the same server-side
// routes with the same rate limits and the same CSRF header; only the code that drives them moved
// out of Stimulus.
import { useRef, useState } from "react";

import Button from "@/components/ui/Button";
import { csrfToken } from "@/lib/csrf";
import { readNonEmptyString, readObject, readString } from "@/lib/payload";

import { solveInvisibleTurnstile } from "./invisibleTurnstile";
import { PASSKEY_MESSAGES, TURNSTILE_DEFAULT_ERROR, authenticationErrorMessage } from "./messages";
import { useCeremonyMessages } from "./useCeremonyMessages";
import { getAssertion, passkeysSupported } from "./webauthn";

export type PasskeyAuthenticationField = {
  label: string;
  placeholder: string;
  min_length: number;
  max_length: number;
  pattern: string;
};

export type PasskeyAuthenticationPanelProps = {
  options_url: string;
  verification_url: string;
  region: string;
  /**
   * Null when an earlier stage of the ceremony already selected the actor, as the org normal
   * sign-in flow does after Entra ID: the server reads the actor from its own pending transaction
   * and ignores anything sent here, so the panel asks for nothing and sends nothing.
   */
  identifier_param: string | null;
  turnstile_site_key: string;
  turnstile_error_message: string;
  /** Null exactly when `identifier_param` is null. */
  field: PasskeyAuthenticationField | null;
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

export default function PasskeyAuthenticationPanel({
  options_url: optionsUrl,
  verification_url: verificationUrl,
  region,
  identifier_param: identifierParam,
  turnstile_site_key: turnstileSiteKey,
  turnstile_error_message: turnstileErrorMessage,
  field,
  submit_label: submitLabel,
}: PasskeyAuthenticationPanelProps) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const [identifier, setIdentifier] = useState("");
  const { error, status, showError, showStatus, clearMessages } = useCeremonyMessages();

  const authenticate = async () => {
    clearMessages();

    if (!passkeysSupported()) {
      showError(PASSKEY_MESSAGES.unsupported);
      return;
    }

    const trimmed = identifier.trim();
    if (identifierParam !== null && !trimmed) {
      showError(PASSKEY_MESSAGES.identifierRequired);
      return;
    }

    try {
      const token = await solveInvisibleTurnstile(
        turnstileSiteKey,
        turnstileErrorMessage || TURNSTILE_DEFAULT_ERROR,
        hostRef.current,
      );
      showStatus(PASSKEY_MESSAGES.fetchingOptions);

      const optionsResponse = await postJson(optionsUrl, {
        ...(identifierParam === null ? {} : { [identifierParam]: trimmed }),
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
      ref={hostRef}
      className="flex flex-col gap-4"
    >
      {/*
        A plain, hand-styled input rather than the shared `TextField`: `TextField` has no prop for
        `autoCapitalize`, and dropping it would change the mobile keyboard behaviour this identifier
        relies on.
      */}
      {field === null ? null : (
        <div className="flex flex-col gap-1">
          <label
            htmlFor="identifier"
            className="text-sm font-medium text-fg"
          >
            {field.label}
          </label>
          <input
            type="text"
            id="identifier"
            value={identifier}
            onChange={(event) => setIdentifier(event.target.value)}
            placeholder={field.placeholder}
            autoComplete="username webauthn"
            autoCapitalize="characters"
            minLength={field.min_length}
            maxLength={field.max_length}
            pattern={field.pattern}
            spellCheck={false}
            required
            className="w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-fg
            placeholder:text-fg-muted"
          />
        </div>
      )}

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
