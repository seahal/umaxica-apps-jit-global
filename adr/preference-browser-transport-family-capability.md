# Preference browser transport: family capability and host-local endpoints

- Status: accepted
- Date: decision approved 2026-10-01; implemented 2026-10-02
- Approval source: the user's preference transport cleanup instruction (2026-10-01), including the
  approved implementation plan.

## Context

The page chrome decided whether to render the theme and cookie-consent controls from the surface
alone (`SurfaceChrome::PREFERENCE_SURFACES = %w(app com org)`), and browser code assumed every host
served `/web/v0/theme` and `/web/v0/cookie` (`new URL("/web/v0/theme", window.location.origin)`).

Neither assumption held. Palm shares the `app` surface with Core but serves no preference endpoint,
and Core serves `/api/v0/preferences/{theme,cookie}` rather than `/web/v0/*`. Palm and Core pages
therefore rendered controls whose reads and writes returned 404. The defect was structural: `app`,
`com`, and `org` name a preference domain, not a statement that a family's pages may offer the
controls, and the browser guessed a path the server never declared.

## Decision

### Capability is a family-and-surface decision

`PreferenceBrowserControlsRegistry` (`app/values`) lists the families whose pages render the
controls and the endpoint each control calls. Only pairs that exist are listed; asking for an
unlisted pair raises.

| Family | app | com | org | Controls |
| --- | --- | --- | --- | --- |
| Base | yes | yes | yes | theme and cookie |
| Auth | yes | yes | yes | theme and cookie (UX transport only, see below) |
| Core | yes | yes | yes | theme and cookie |
| Warp | yes | yes | yes | theme and cookie |
| Palm | no | — | — | none |
| Edit | — | — | no | none |

Xper renders no chrome and is not listed (`adr/xper-phase-zero-bootstrap.md`). The former
`Edit::Org::ApplicationController#chrome_preference_surface?` override is replaced by the `edit`
row.

### The server declares the endpoint

`SurfaceChrome` hands `chrome.theme_controls.endpoint_url` and `chrome.cookie_controls.endpoint_url`
to React, and the Base and Auth ERB layouts hand the same values to the Stimulus controllers as
`data-theme-endpoint-url-value` and `data-cookie-banner-endpoint-url-value`. Browser code resolves
the declared path against the current origin and throws when the result would leave it
(`sameOriginEndpoint` in `src/lib/request.ts`). A family without the capability gets no controls, so
its pages make no preference request.

### Transport stays host-local

Preference access, refresh, and DBSC credentials are host-only cookies
(`adr/cookie-domain-scope-by-surface.md`); a request to another host would carry none of them. Each
family therefore answers `/api/v0/preferences/{theme,cookie}` on its own host:

- no cross-origin fetch to Base, no CORS allowlist, no CSP `connect-src` addition, and no extra
  trusted origins for these endpoints;
- no Warp-to-Core or other server-side preference proxy;
- PATCH runs through each family's ordinary Rails forgery protection on its own host.

Browser-readable UX projection cookies (`ct`, `language`, `tz`, and the rest) keep their existing
domain-scoped contract. They are projections Rails never trusts as input, not credentials.

### Endpoint ownership is not preference authority

Serving the endpoint on a host is HTTP transport. The preference domain behavior is shared:
`PreferenceWebThemeEndpoint` and `PreferenceWebCookieEndpoint` perform the read and update
(including principal mirror sync, audit, and access-token reissue), and `PreferenceBrowserApi`
supplies the one HTTP contract every family uses (406/415 before CSRF and credentials,
`Cache-Control: no-store`, RFC 9457 problems with JSON Pointer `errors` on 422). No family carries a
copy of that logic. Base remains the preference HTML authority (`adr/identity-authority-boundary.md`).

### Auth serves a non-security UX transport adapter only

Auth remains ceremony-only (`adr/base-auth-ceremony-and-seven-rp-boundary.md`). Its theme and
cookie endpoints exist so ceremony pages can show and record display preferences on the Auth host,
where the visitor's host-only preference credentials live. The preference state they read or write
is UX state and must never be used as authentication proof, user presence, authorization, operator
proof, tenant or account selection, AAL, or step-up evidence
(`docs/architecture/preference-behavior-contract.md`). This adds no IdP, session, account,
authorization, or general settings authority to Auth.

### Palm and Edit

Palm keeps its native bearer resource-server boundary and gains no browser preference API. Its use of
the `ri` request context is unrelated and unchanged. Edit offers no interactive controls and gains
no preference API; preference editing stays on Base.

## Consequences

- A family gains the controls only by adding a registry row and serving the endpoint; the chrome
  request tests and the contract matrix (`test/integration/preference_browser_api_contract_test.rb`)
  hold the two together.
- Invalid theme or consent input is now a 422 problem instead of a silent 200 (theme) or a
  mislabelled 401 (cookie). Successful response shapes are unchanged.
- Preference lifecycle semantics (anonymous preference, adoption, reconciliation, refresh rotation,
  sign-out rotation and safe-copy, cookie consent handling) are unchanged.

## Follow-up

`PreferenceClassRegistry.for_controller_path` still derives the preference class from the controller
namespace. Replacing that with an explicitly passed `app | com | org` surface touches every preference
concern, so it is left to a separate change.
