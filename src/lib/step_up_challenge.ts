const STEP_UP_ENTRY_PATH = "/verification";
const STEP_UP_CHALLENGE = /(?:^|,\s*)Bearer\s+error="insufficient_user_authentication"(?:,|$)/iu;

export type StepUpChallengeResponse = {
  status: number;
  headers: Headers | Readonly<Record<string, string>>;
};

function authenticateHeader(headers: StepUpChallengeResponse["headers"]): string | null {
  if (headers instanceof Headers) {
    return headers.get("WWW-Authenticate");
  }

  const header = Object.entries(headers).find(
    ([name]) => name.toLowerCase() === "www-authenticate",
  );
  return header?.[1] ?? null;
}

/** Recognizes the RP challenge and opens its explicit entry without replaying the rejected request. */
export function handleStepUpChallenge(response: StepUpChallengeResponse): boolean {
  if (
    response.status !== 401 ||
    !STEP_UP_CHALLENGE.test(authenticateHeader(response.headers) ?? "")
  ) {
    return false;
  }

  const current = new URL(window.location.href);
  const entry = new URL(STEP_UP_ENTRY_PATH, current.origin);
  entry.searchParams.set("return_target", current.pathname);

  const region = current.searchParams.get("ri");
  if (region !== null) {
    entry.searchParams.set("ri", region);
  }

  window.location.assign(entry.href);
  return true;
}
