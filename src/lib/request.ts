// Request helpers shared by the React chrome and by pages that talk to Rails JSON endpoints
// directly. Inertia visits carry their own CSRF handling; these are for the plain `fetch` calls
// that predate the migration and stay as JSON endpoints.

/** Preference context carried across hosts in the query string. Mirrors SurfaceChrome::PREFERENCE_QUERY_KEYS. */
const PREFERENCE_QUERY_KEYS = ["ri", "lx", "ct", "tz", "cu", "df", "tf", "mo", "dn", "ps"] as const;

export function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? "";
}

/** The preference parameters present on the current URL, in the order they are declared. */
export function preferenceQueryParameters(): [string, string][] {
  const search = new URLSearchParams(window.location.search);

  return PREFERENCE_QUERY_KEYS.flatMap((key) => {
    const value = search.get(key);
    return value ? [[key, value] as [string, string]] : [];
  });
}

/**
 * Resolves an endpoint path the server declared for this page against the current origin, and
 * refuses anything that would leave it. Preference credentials are host-only cookies, so a request
 * to another host would carry none of them; failing here keeps a misdeclared endpoint from silently
 * becoming a cross-origin call. The path is never chosen by the browser.
 */
export function sameOriginEndpoint(endpointUrl: string): URL {
  const endpoint = new URL(endpointUrl, window.location.origin);
  if (endpoint.origin !== window.location.origin) {
    throw new Error(`endpoint must be same-origin: ${endpointUrl}`);
  }
  return endpoint;
}
