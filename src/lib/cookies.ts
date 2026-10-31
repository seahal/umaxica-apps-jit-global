// Reading the cookies Rails publishes to the browser on purpose, through the Cookie Store API.
//
// The authoritative preference state lives in the verified preference JWT, which is httponly and
// so unreadable here. Alongside it the server writes small JS-readable projections - the theme in
// `ct`, the recorded consent decision in `preference_consented` - precisely so the first paint can
// be correct before any request is made.
//
// They are read here and never written. A projection written by this file would be a second source
// of truth for a decision the server owns, and consent is the last state that should have two.
//
// `document.cookie` parsing is deliberately gone: it is a synchronous string split that every
// caller had to re-implement or import a helper for, and it cannot tell an absent cookie from one
// this document may not see. `window.cookieStore` answers the same question as a structured record
// and is Baseline since June 2025 (Chrome/Edge 87+, Firefox 140+, Safari 18.4+). It exists only in
// a secure context, which every deployed surface is and `localhost` development counts as.

/**
 * The document's cookie store.
 *
 * Absent means the document is not in a secure context or the browser predates the API. Neither is
 * a state this application can read a cookie in, so it says which of its expectations was not met
 * rather than reporting every cookie as absent - "no consent recorded" and "cannot tell" are
 * different answers, and only one of them should raise a consent banner.
 */
function cookieJar(): CookieStore {
  const available = typeof window !== "undefined" && typeof window.cookieStore !== "undefined";

  if (!available) {
    throw new Error(
      "window.cookieStore is unavailable: the Cookie Store API needs a secure context " +
        "(HTTPS, or localhost in development) and Chrome/Edge 87+, Firefox 140+ or Safari 18.4+.",
    );
  }

  return window.cookieStore;
}

/**
 * What a cookie's stored value means to the application.
 *
 * The store hands back the value as stored, so the percent-encoding Rails writes is undone here,
 * the same way `document.cookie` readers had to. `CookieListItem.value` is optional in the IDL,
 * and a cookie written with an empty value is a cookie that names nothing - both read as absent.
 */
function cookieValue(cookie: CookieListItem | null | undefined): string | null {
  return cookie?.value ? decodeURIComponent(cookie.value) : null;
}

/** The value of a cookie by name, or null when the document does not carry it. */
export async function readCookie(name: string): Promise<string | null> {
  return cookieValue(await cookieJar().get(name));
}

/** A same-name ambiguity is not a usable value. */
export async function readUniqueCookie(name: string): Promise<string | null> {
  const matches = (await cookieJar().getAll()).filter((cookie) => cookie.name === name);
  return matches.length === 1 ? cookieValue(matches[0]) : null;
}

/**
 * Calls back with a cookie's new value whenever it changes, and with null when it is deleted.
 * Returns an unsubscribe function.
 *
 * The store reports every script-visible change to this document's cookies, including the ones a
 * response's `Set-Cookie` header makes, which is what the server writing a preference is. That is
 * a narrower signal than the navigation events this used to be inferred from: a `turbo:load` or a
 * successful Inertia visit says a page arrived, not that the cookie behind it moved, so the value
 * had to be re-read on every navigation to find out - and a cookie the server changed outside a
 * navigation was never noticed at all.
 */
export function watchCookie(name: string, listener: (value: string | null) => void): () => void {
  const store = cookieJar();

  const onChange = (event: CookieChangeEvent) => {
    const changed = event.changed.find((cookie) => cookie.name === name);

    if (changed) {
      listener(cookieValue(changed));
      return;
    }

    if (event.deleted.some((cookie) => cookie.name === name)) {
      listener(null);
    }
  };

  store.addEventListener("change", onChange);

  return () => store.removeEventListener("change", onChange);
}

/**
 * Whether the visitor has already answered the cookie banner.
 *
 * The cookie is `PreferenceIoKeys::Cookies::CONSENTED`, written by
 * `PreferenceConsentedBuffer#set_preference_consented_buffer!` as "1" or "0" whenever the server
 * mints or refreshes the preference token. It is `SameSite=Strict`, so it is absent on the first
 * cross-site inbound hit; absent reads as "not answered", which shows the banner. That is the safe
 * direction to be wrong in, and the endpoint corrects it a moment later either way.
 */
export async function hasRecordedCookieConsent(): Promise<boolean> {
  return (await readCookie("preference_consented")) === "1";
}
