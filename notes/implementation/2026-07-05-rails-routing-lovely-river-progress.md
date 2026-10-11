# Rails Routing Lovely River Progress

Date: 2026-07-05 UTC

## Summary

This pass advanced the route-naming cleanup without breaking existing path helpers or external path
contracts.

## What Changed

- Renamed edge token route resources to noun forms in `config/routes/base.rb`,
  `config/routes/auth.rb`, and `config/routes/core.rb`.
- Renamed base session-revocation routes to noun `revocation` resources while keeping the existing
  helper aliases.
- Kept the public paths stable:
  - `/edge/v0/token/check`
  - `/edge/v0/token/refresh`
  - `/preference/reset`
- Kept the session revocation paths stable:
  - `/identity/sessions`
  - `/identity/other_sessions`
- Added explicit controller mappings so Rails continues to resolve the existing controllers:
  - `ChecksController`
  - `RefreshesController`
  - `ResetsController`
- Kept legacy helper names available with `as:` aliases where the repo already used them.

## Verification

- `bin/rails test test/unit/security/identity_authority_inversion_guard_test.rb test/integration/routes/base_authority_route_contract_test.rb test/integration/routes/core_route_contract_test.rb test/integration/routes/auth_sign_ceremony_route_contract_test.rb test/security/invariants/withdrawn_resource_refresh_invariant_test.rb test/controllers/base/preference_authority_slice_1f_test.rb test/integration/cross_surface_token_test.rb`

## Notes

- This was an incremental, compatibility-preserving step. The broader session revocation
  consolidation in `config/routes/base.rb` remains for a later batch.
- The source-level route names now read as nouns, but helper aliases remain unchanged for callers
  that already depend on them.
