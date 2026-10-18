// React port of `src/controllers/passkey_registration_controller.js`.
//
// Same three-step ceremony against the same endpoints: solve an invisible Turnstile token, POST it
// to the options endpoint, run `navigator.credentials.create`, and POST the attestation to the
// verification endpoint. The attestation encoding keeps the `transports` field the Stimulus
// controller sent, because the server stores it.
import { useRef, useState } from "react";

import Button from "@/components/ui/Button";
import TextField from "@/components/ui/TextField";
import { normalizeCreationOptions } from "@/controllers/webauthn_utils";
import { csrfToken } from "@/lib/csrf";
import { readNonEmptyString, readObject, readString } from "@/lib/payload";

import { solveInvisibleTurnstile } from "./invisibleTurnstile";
import { PASSKEY_MESSAGES, TURNSTILE_DEFAULT_ERROR, registrationErrorMessage } from "./messages";
import { useCeremonyMessages } from "./useCeremonyMessages";
import {
  type AttestationCredential,
  bufferToBase64url,
  isAttestationCredential,
  passkeysSupported,
} from "./webauthn";

export type PasskeyRegistrationPanelProps = {
  options_url: string;
  verification_url: string;
  turnstile_site_key: string;
  turnstile_error_message: string;
  description_label: string;
  description_placeholder: string;
  submit_label: string;
};

type RegistrationCredential = {
  id: string;
  rawId: string;
  type: string;
  authenticatorAttachment: string | null;
  response: {
    clientDataJSON: string;
    attestationObject: string;
    transports: string[];
  };
  clientExtensionResults: AuthenticationExtensionsClientOutputs;
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

function encodeAttestation(credential: AttestationCredential): RegistrationCredential {
  const { response } = credential;

  return {
    id: credential.id,
    rawId: bufferToBase64url(credential.rawId),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment ?? null,
    response: {
      clientDataJSON: bufferToBase64url(response.clientDataJSON),
      attestationObject: bufferToBase64url(response.attestationObject),
      transports: typeof response.getTransports === "function" ? response.getTransports() : [],
    },
    clientExtensionResults: credential.getClientExtensionResults(),
  };
}

export default function PasskeyRegistrationPanel({
  options_url: optionsUrl,
  verification_url: verificationUrl,
  turnstile_site_key: turnstileSiteKey,
  turnstile_error_message: turnstileErrorMessage,
  description_label: descriptionLabel,
  description_placeholder: descriptionPlaceholder,
  submit_label: submitLabel,
}: PasskeyRegistrationPanelProps) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const [description, setDescription] = useState("");
  const { error, status, showError, showStatus, clearMessages } = useCeremonyMessages();

  const register = async () => {
    clearMessages();

    if (!passkeysSupported()) {
      showError(PASSKEY_MESSAGES.unsupported);
      return;
    }

    try {
      const token = await solveInvisibleTurnstile(
        turnstileSiteKey,
        turnstileErrorMessage || TURNSTILE_DEFAULT_ERROR,
        hostRef.current,
      );
      showStatus(PASSKEY_MESSAGES.fetchingOptions);

      const optionsResponse = await postJson(optionsUrl, { "cf-turnstile-response": token });
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

      showStatus(PASSKEY_MESSAGES.creating);
      const created = await navigator.credentials.create({
        publicKey: normalizeCreationOptions(options),
      });
      if (!created || !isAttestationCredential(created)) {
        throw new Error(PASSKEY_MESSAGES.registrationFailed);
      }

      showStatus(PASSKEY_MESSAGES.verifying);
      const verificationResponse = await postJson(verificationUrl, {
        challenge_id: challengeId,
        credential: encodeAttestation(created),
        description,
      });

      if (!verificationResponse.ok) {
        const failure = await readFailure(
          verificationResponse,
          PASSKEY_MESSAGES.registrationFailed,
        );
        if (!failure) {
          return;
        }
        throw failure;
      }

      const result: unknown = await verificationResponse.json();
      const redirectUrl = readString(result, "redirect_url");

      showStatus(PASSKEY_MESSAGES.registrationComplete);
      if (redirectUrl) {
        window.location.href = redirectUrl;
      } else {
        window.location.reload();
      }
    } catch (caught) {
      showError(registrationErrorMessage(caught));
    }
  };

  return (
    <div
      ref={hostRef}
      className="flex flex-col gap-4"
    >
      <TextField
        label={descriptionLabel}
        autoComplete="off"
        value={description}
        onChange={setDescription}
        placeholder={descriptionPlaceholder}
        maxLength={100}
      />

      {error ? (
        <p
          role="alert"
          className="text-base text-error"
        >
          {error}
        </p>
      ) : null}
      <output
        aria-atomic="true"
        className="text-base text-fg-muted"
      >
        {status}
      </output>

      <div>
        <Button
          type="button"
          onPress={() => void register()}
        >
          {submitLabel}
        </Button>
      </div>
    </div>
  );
}
