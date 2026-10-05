// The passkey requirement of the sign-up checkpoint.
//
// The ceremony is the one `src/controllers/passkey_registration_controller.js` ran from the
// `shared/passkeys/registration` partial, against the same two endpoints and with the same
// attestation encoding, including the `transports` field the server stores. The checkpoint version
// travels with the attestation because the server re-validates it before clearing the requirement.
//
// The partial supplied no Turnstile site key on this page and the options endpoint verifies no
// token, so the ported ceremony has no Turnstile step. Nothing the server checks changed.
import { useState } from "react";

import Button from "@/components/ui/Button";
import Page from "@/components/ui/Page";
import TextField from "@/components/ui/TextField";
import { normalizeCreationOptions } from "@/controllers/webauthn_utils";
import { PASSKEY_MESSAGES, registrationErrorMessage } from "@/features/auth/passkeys/messages";
import { useCeremonyMessages } from "@/features/auth/passkeys/useCeremonyMessages";
import {
  type AttestationCredential,
  bufferToBase64url,
  isAttestationCredential,
  passkeysSupported,
} from "@/features/auth/passkeys/webauthn";
import { readNonEmptyString, readObject, readString } from "@/lib/payload";

import { csrfToken } from "./csrf";

export type SignUpPasskeyRegistrationProps = {
  title: string;
  /** Options endpoint; POST returns the WebAuthn challenge. */
  begin_url: string;
  /** Verification endpoint; POST carries the attestation. */
  finish_url: string;
  /** Where the server sends the visitor when the requirement is cleared. */
  success_redirect_url: string;
  checkpoint_version: number;
  description_label: string;
  description_placeholder: string;
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

function encodeAttestation(credential: AttestationCredential) {
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

export default function SignUpPasskeyRegistration({
  title,
  begin_url: beginUrl,
  finish_url: finishUrl,
  success_redirect_url: successRedirectUrl,
  checkpoint_version: checkpointVersion,
  description_label: descriptionLabel,
  description_placeholder: descriptionPlaceholder,
  submit_label: submitLabel,
}: SignUpPasskeyRegistrationProps) {
  const [description, setDescription] = useState("");
  const { error, status, showError, showStatus, clearMessages } = useCeremonyMessages();

  const register = async () => {
    clearMessages();

    if (!passkeysSupported()) {
      showError(PASSKEY_MESSAGES.unsupported);
      return;
    }

    try {
      showStatus(PASSKEY_MESSAGES.fetchingOptions);
      const optionsResponse = await postJson(beginUrl, {});
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
      const verificationResponse = await postJson(finishUrl, {
        challenge_id: challengeId,
        credential: encodeAttestation(created),
        description,
        checkpoint_version: checkpointVersion,
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

      showStatus(PASSKEY_MESSAGES.registrationComplete);
      const destination = readNonEmptyString(result, "redirect_url") ?? successRedirectUrl;
      if (destination) {
        window.location.href = destination;
      } else {
        window.location.reload();
      }
    } catch (caught) {
      showError(registrationErrorMessage(caught));
    }
  };

  return (
    <Page
      title={title}
      width="narrow"
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
        <Button onPress={() => void register()}>{submitLabel}</Button>
      </div>
    </Page>
  );
}
