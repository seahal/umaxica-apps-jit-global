// Solves a Turnstile challenge invisibly and hands back the token, for ceremonies that post JSON
// instead of submitting a form.
//
// The invisible widget is rendered into a detached container, its callback resolves with the token,
// and any error or expiry rejects. A rejection means the challenge could not be presented, which
// the caller must surface - it is never treated as a passed challenge. The server still verifies
// the token.
import { waitForTurnstileApi, type TurnstileOptions } from "@/lib/turnstile";

export async function solveInvisibleTurnstile(
  siteKey: string,
  errorMessage: string,
  host: HTMLElement | null,
): Promise<string> {
  if (!siteKey) {
    throw new Error(errorMessage);
  }

  const api = await waitForTurnstileApi(errorMessage);

  return new Promise<string>((resolve, reject) => {
    try {
      const container = document.createElement("div");
      // `hidden` rather than an inline style: it is the platform attribute for "not rendered and

      // not announced", and it keeps the widget host out of the accessibility tree too.

      container.hidden = true;
      (host ?? document.body).append(container);

      const options: TurnstileOptions = {
        sitekey: siteKey,
        size: "invisible",
        callback: (token: string) => resolve(token),
        "error-callback": () => reject(new Error(errorMessage)),
        "expired-callback": () => reject(new Error(errorMessage)),
      };

      api.render(container, options);
    } catch (error) {
      // The caller is given the visitor-facing message; the underlying failure is only useful
      // here.
      // oxlint-disable-next-line no-console
      console.error("Turnstile token request failed:", error);
      reject(new Error(errorMessage));
    }
  });
}
