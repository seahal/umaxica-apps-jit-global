# WU-03: `/edge/v0/cookie` removed

- Date: 2026-10-23. Commit before the change: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`;
  the change is uncommitted. The worktree also held unrelated uncommitted work of another session
  (locales, PWA offline page), not touched here.
- Decision: D-63 (authentication cycle `one.md`).

## Change

- Routes `GET/PATCH/PUT /edge/v0/cookie` removed from the three Base surfaces
  (`config/routes/base.rb`); `/edge/v0/token/*` unchanged.
- Deleted `Base::{App,Com,Org}::Edge::V0::CookiesController` and their controller and parity tests.
- Removed helpers used only by them from `PreferenceWebCookieEndpoint`
  (`apply_consented_update_from_request!`, `requested_cookie_consent_attrs`, `cast_cookie_boolean`).
- Guard tests updated to the final route set (legacy namespace pin, route ownership, skip allowlists,
  withdrawal-gate allowlist, credential-recovery matrix).
- New `test/integration/routes/base_retired_edge_cookie_route_test.rb` (A03-1).
- `docs/architecture/preference-behavior-contract.md` updated.

## Comparison with `/api/v0/preferences/cookie` (A03-2)

The removed endpoint also returned a `dbsc` payload and a DBSC registration header. Base has no
host-local Preference DBSC endpoint (`adr/credential-response-nondisclosure.md`: families without one
advertise no registration), so nothing the browser relies on moved; no caller existed in `app/` or
`src/`.

## Verification

- `bin/rails test` on the route guard, matrix, ownership, allowlist, withdrawal-gate, Core route
  contract and Base `api/v0/preferences/cookie` tests: 103 runs, 0 failures, 0 errors.
- New route test: 2 runs, 15 assertions, 0 failures.
- `grep -rn "edge/v0/cookie" app config src`: only the Core retired-route assertion in tests (A03-3).
- RuboCop on changed Ruby files: no offenses.
