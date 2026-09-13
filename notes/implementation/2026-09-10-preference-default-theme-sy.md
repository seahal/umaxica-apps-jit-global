# Preference Default Theme `sy` Implementation Notes

## Context

- Original plan/spec: conversation request to stop installing `Actor::Preference::NULL` as the
  request default and to delete the `null` → `sy` color-theme cookie path.
- Related decisions/docs/plans: `docs/architecture/current_context.md`,
  `docs/architecture/preference.md`, `adr/preference-soft-bubble-doctrine.md` (still describes the
  older NULL+overlay fallback).
- Implementation date: 2026-09-10

## Decisions Made During Implementation

- Decision: `set_current_context` installs `Actor::Preference.new` (theme `sy`). Missing JWT
  hydration uses the same default object, not `NULL.with_cookie`.
  - Why: `NULL` meant "no preference loaded" and `set_color_theme` treated that as "write `sy`",
    which overwrote a live Preference JWT `ct=dr` on Auth `GET /web/v0/theme`.
  - Alternatives considered: skip `set_color_theme` on Auth theme controllers (matches Base/Side).
    Rejected for this change because the request was to make `sy` the real default instead of a
    null-object conversion.
  - Follow-up needed: `adr/preference-soft-bubble-doctrine.md` still says Bearer/OIDC falls back
    to `NULL`+overlay. Promote a doc/ADR update if that ADR is still treated as current.

- Decision: `set_color_theme` writes `ct` from the Preference JWT payload when it is present,
  otherwise from `Actor.preferences.theme` (default `sy`). It no longer returns early on `null?`
  or assigns `theme ||= "sy"`.
  - Why: Auth theme JSON skips `set_preferences_cookie` / `set_current_actor`, so Actor alone
    still had the default when the JWT cookie already carried `dr`.
  - Alternatives considered: un-skip `set_current_actor` on Auth theme controllers. Not required
    once `set_color_theme` reads the same JWT cookie the JSON action already decoded.
  - Follow-up needed: none.

## Deviations From Plan

- Change: `current_preference_payload_preferences` now calls `load_access_token_payload` when
  the controller can decode a Preference JWT.
  - Why: theme JSON skips `set_preferences_cookie`, so the payload was otherwise empty during
    `set_current_actor` on HTML requests that still have the cookie.
  - Risk: extra decode only when `@preference_payload` is not already a Hash; the transport
    method short-circuits after the first successful decode.
  - Follow-up: none.

## Review Notes

- Tests run: Auth app/org theme controller tests, preference base tests, actor support unit
  tests, actor lifecycle, public controller, JWT color theme, Base app theme.
- Tests not run: full `bin/rails test`.
- Documentation promotion needed: ADR fallback sentence still describes NULL+overlay.
