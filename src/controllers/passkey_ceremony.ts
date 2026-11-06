// The JSON request/response handling both Stimulus passkey controllers share.
//
// A passkey ceremony is two POSTs around one call to the credential API, and the two controllers
// differ only in their URLs, their payloads and their copy. Everything about how a response is
// read -- including that an expired session answers with a redirect rather than an error -- is the
// same, and it is the part that must not drift between the two.
import { csrfToken } from "@/lib/csrf";
import { readString } from "@/lib/payload";
import { handleStepUpChallenge } from "@/lib/step_up_challenge";

/**
 * Signals that the response was an authentication redirect and the page has been reloaded.
 *
 * The return type stays `unknown` because a JSON body is unknown; callers compare against this
 * sentinel before reading the payload.
 */
export const CEREMONY_REDIRECTED = Symbol("ceremony redirected");

export async function postCeremonyJson(
  url: string,
  body: Record<string, unknown>,
  failureMessage: string,
): Promise<unknown> {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    body: JSON.stringify(body),
  });

  if (response.ok) {
    const payload: unknown = await response.json();
    return payload;
  }

  if (handleStepUpChallenge(response)) {
    return CEREMONY_REDIRECTED;
  }

  const contentType = response.headers.get("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const payload: unknown = await response.json();
    throw new Error(readString(payload, "error") ?? failureMessage);
  }

  // The session ended mid-ceremony; reloading lands on the sign-in screen rather than reporting a
  // ceremony failure the visitor cannot act on.
  if (response.status === 401 || response.status === 302) {
    window.location.reload();
    return CEREMONY_REDIRECTED;
  }

  throw new Error(failureMessage);
}

/** Maps the credential API's own failures onto the copy each ceremony shows for them. */
export function ceremonyErrorMessage(
  error: unknown,
  messages: { readonly [name: string]: string } & { fallback: string },
): string {
  if (error instanceof Error) {
    const byName = messages[error.name];
    if (byName !== undefined) {
      return byName;
    }
    if (error.message) {
      return error.message;
    }
  }

  return messages.fallback;
}
