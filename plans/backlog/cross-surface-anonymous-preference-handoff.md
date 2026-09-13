# Cross-Surface Anonymous Preference Handoff

## Status

Backlog. Raised 2026-09-09 while fixing the preference/i18n propagation audit item.

## Problem

An anonymous visitor who sets a preference (e.g. language = English) on
`www.umaxica.app/preference/language/edit` sees it applied on www, but a first visit to
`auth.umaxica.app` or `side-jp.umaxica.app` renders in the region-seeded default instead.

Root cause, all confirmed:

- The canonical preference transport is the `preference_access` JWT cookie. It is `__Host-`
  prefixed and written with `domain: false` (`PreferenceCookieWriter`, `preference_base.rb`
  `preference_auth_cookie_options`), so it is host-scoped and does **not** cross
  `www` → `auth` → `side`.
- The JS-readable `language` / `ct` / `tz` cookies are domain-scoped (`.umaxica.<tld>`) and do
  cross, but Rails deliberately does not read them as input
  (`adr/theme-preference-cookie-and-param-contract.md`).
- `?lx` / `?ct` / `?tz` overlays would propagate a choice, but
  `PreferenceGlobal#default_url_options` forwards only `requested_context` (the current request's
  params), and `adr/localization-preference-flow.md` — pinned by
  `test/integration/preference_global_param_context_test.rb` — deliberately does **not** auto-add
  those keys to generated URLs.

Signed-in users are unaffected: `PreferenceAdoption` reconciles each surface's token with the
shared per-account preference (`client_preferences` etc.) on every request.

## Options

1. **Signed cross-surface preference param.** When Rails generates a link/redirect whose `host:`
   belongs to a different surface family, attach a short signed token carrying the resolved
   overlay subset. The destination surface verifies it and seeds its token on first render. Keeps
   `__Host-` scoping and the "no bare `lx` on same-surface URLs" contract.
2. **Read-only domain-scoped projection cookie.** A separate, explicitly-scoped, signed
   `preference_projection` cookie (`.umaxica.<tld>`, no credentials) that surfaces MAY read as a
   seed when they have no host-scoped token. Needs an ADR because it introduces a second readable
   source with an explicit precedence (below the host-scoped token, above region seeding).
3. **Do nothing for anonymous.** Document that anonymous cross-surface preference is not carried
   and rely on each surface's own preference screen. Lowest effort, worst UX.

Option 1 is preferred: it reuses the existing signed-param machinery (`pt`/`nt` lanes), does not
weaken cookie scoping, and does not add a competing readable source.

## Acceptance

- Set `lx=en` through the supported www preference flow; a first visit to `auth` and to `side`
  (both anonymous) renders English.
- A stale/forged domain cookie still cannot override the canonical host-scoped token
  (already covered by `test/integration/preference_read_symmetry_test.rb`).
- `preference_global_param_context_test.rb` same-surface expectations stay green.
