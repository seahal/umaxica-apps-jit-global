# Localization Preference Flow

## Status

Accepted on 2026-04-07.

> **Hydration and dynamic region seeding update (2026-05-30, updated 2026-06-18):** The effective
> request locale is chosen by `apply_localization_preferences` from `Actor.preferences.language`.
> `Actor.preferences` is hydrated from the Preference JWT payload, the signed projection of the
> database source of truth. Auth access tokens do not carry or read the obsolete `prf` preference
> claim. Language priority is: `?lx` request-local overlay, explicit language from the
> `explicit_fields` marker, dynamic `?ri` seeding (`jp` -> `ja`, `us` -> `en`) for unset users, then
> the default `ja`.

> **Regional-bundle reset (2026-09-09, currency added 2026-09-11):** A `/preference/region` write
> rewrites all region-owned locale defaults — language, date format, clock format, and currency —
> to the region's values in one transaction and marks each explicit (`jp` → `ja` / ISO / 24h /
> JPY, `us` → `en` / US / 12h / USD). This extends the region → language force-update that already
> existed. Each value stays overridable on its own screen. See
> `docs/architecture/preference.md` "Region is a regional-bundle reset".

## Context

GitHub issue `#631` tracked completion of the localization preference flow across the sign surfaces.
The target was to confirm region, language, and timezone behavior for `app`, `org`, and `com`, and
to keep the UI copy and regression coverage aligned.

## Decision

The sign preference flow supports region, language, and timezone as first-class preference inputs on
all three sign surfaces: `app`, `org`, and `com`.

The request and cookie contract keeps:

- `ri` for region
- `lx` for language
- `tz` for timezone

The preference UI, redirect behavior, and persisted state use the same contract across all three
surfaces.

User-facing timestamps on identity Activities and Sessions use the hydrated `Actor.preferences`
projection as their source of truth. Rendering applies the preference timezone first, then the
date-format preference (`ISO`, `US`, or `UK`) and clock-format preference (`24h` or `12h`). Browser
locale and region-only request parameters do not choose date or clock formatting. Lists always sort
the underlying absolute timestamp before rendering; localized display strings are not sort keys.

Region resolution follows request-context precedence:

1. An explicit valid `ri` request parameter wins for the current request.
2. When `ri` is missing, the persisted preference context supplies the redirect value.
3. When neither request nor persisted preference has a region, the default region is `jp`.

The system must not rewrite an explicit `?ri=us` to the persisted value merely because the saved
preference is `jp`. Persisted preference is a fallback for missing request context, not an override
for explicit request context.

## Evidence

- `test/integration/sign_preference_test.rb` runs the same preference assertions for `app`, `org`,
  and `com` through the shared `DOMAINS` matrix.
- The same integration file verifies:
  - `lx` changes locale
  - region updates persist
  - timezone updates persist
  - default language and timezone values initialize cookies and JWT preference payloads
  - localized option labels and localized error handling work across surfaces
- `test/integration/preference_global_param_context_test.rb` verifies `lx` and `tz` propagation
  behavior in navigation and internal links.
- View and controller pairs exist for all sign surfaces:
  - `app/views/sign/app/preference/regions/edit.html.erb`
  - `app/views/sign/app/preference/region/languages/edit.html.erb`
  - `app/views/sign/app/preference/region/timezones/edit.html.erb`
  - matching `org` and `com` counterparts

## Consequences

- Localization behavior is now part of the stable preference contract, not an incomplete follow-up.
- Future work should extend this flow without changing the `ri` / `lx` / `tz` keys casually.

## Current Operational Clarification

As of the current controller-boundary migration, `ri` is mandatory request context on the sign
`app`, `org`, and `com` surfaces. Earlier implementations had routes where `ri` could be absent; the
current surfaces should redirect missing or invalid `ri` values to a valid `ri`.

`lx` and `tz` remain optional request-local context. They can affect the current request when
present and valid, but they are not preference write paths. Persistent preference changes must go
through the dedicated preference write endpoints, which update the database and reissue the
preference access token.

## Related

- Former plan: `plans/backlog/gh631-localization-preference-flow.md`
- Related contract: `adr/theme-preference-cookie-and-param-contract.md`
