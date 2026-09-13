# RFC 9068 access-token profile hardening

Date: 2026-09-11. Branch `feature`, base commit `65d61c2d0`. All commands ran inside the
`global-devcontainer-core` container (the host shell lacks the compose environment).

## Starting state

- `bin/rails test` could not load: `test/controllers/concerns/authentication_current_resource_resolver_coverage_test.rb`
  had a stray `do:` (introduced in `65d61c2d0`).
- With that file excluded: 12929 runs, 2 failures, 8 errors. One was caused by the JWT work
  (`ArchitectureBaselineTest`: `authentication_jwt_configuration.rb` had 7 explicit-visibility
  offenses, baseline 6). The other nine are listed under "Pre-existing failures".

## Defects fixed

- Development and test shared the issuer `urn:umaxica:test:*`. Local issuers are now
  `urn:umaxica:<rails-env>:{auth,preference}`.
- Silent fallbacks removed: auth keyring audience `umaxica-api`, preference audiences
  `base.*.localhost`, jump gateway audience outside local environments, and the
  `AUTH_JWT_LEEWAY_SECONDS` / `PREFERENCE_JWT_LEEWAY_SECONDS` default. Leeway is now a fixed
  30-second constant.
- Production checks now run at boot (`AuthenticationJwtConfiguration.validate!`,
  `PreferenceJwtConfiguration.validate!`). They reject issuers or audiences containing
  development/test markers, loopback hosts, or the `.test` TLD.
- The auth verification keyring is no longer inferred from host substrings. It is the caller's
  `jwt_issuer_id:`, or `auth` when none is given.
- Preference host and audience matching is exact: the `host` claim must equal the computed host
  scope and share the request's registrable domain, and `aud` must contain that scope.
- Legacy code removed:
  - `extract_public_id`'s fallback to `sub`
  - payload `typ` in diagnostics
  - `JitSecurityJwtKeyring.encode` deriving the header `typ` from the payload (`typ:` is now
    required)
  - `token_type` and `expected_token_type`
  - `act`-named helpers, now `extract_resource_type` / `resource_type_scope_matches?`
- `scope` is now required as a non-empty string in the shared profile.

## Tests added

`test/values/security_jwt_access_token_negative_cases_test.rb` covers:

- ES256, ES512, RS256, PS256, HS256 and `none` rejected for both token families
- tokens signed by another keyring rejected
- missing or malformed `client_id`, `exp`, `jti`, `iss`, `aud`, `iat`
- numeric `sub`, array or missing `scope`, and a future `nbf`
- `scp`, `act` and payload `typ` rejected
- a legacy-format token rejected
- preference: expired token, numeric or mismatched `sub`, sibling host, and an `aud` missing the host scope
- the dev/test issuer boundary, and production boot validation (rejects non-production values, accepts production values)
- fixed leeway, and a required explicit JOSE `typ`

Existing tests were updated to the new contract.

## Results

- Focused JWT set, 15 files and directories: 1071 runs, 0 failures, 0 errors.
- `bin/rubocop` on the changed Ruby files: no offenses.
- `RAILS_ENV=test bin/rails architecture:baseline`: the counts only went down; the two JWT
  configuration modules dropped out of the baseline.
- `bun run test`: 86 files, 1064 tests passed (no frontend change).
- Final `bin/rails test`: 12952 runs, 1 failure, 8 errors, 2 skips.

## Pre-existing failures

All nine remaining failures also failed, with identical messages, in the first full run before
this work began:

- `test/controllers/auth/com/up/checkpoint_telephone_controller_test.rb` (5):
  `visitor_passkey_statuses` foreign key violation
- `test/controllers/auth/com/sign/up/check/telephone/checkpoint_flow_test.rb` (1):
  `visitor_secret_credential_statuses` foreign key violation
- `test/controllers/base/identity_credential_management_test.rb` (1): missing status/kind validation
- `test/integration/identity_settings_page_coverage_test.rb` (1): missing status/kind validation
- `test/controllers/auth/com/sign/up/check/email/birthdates_controller_test.rb` (1): 404

Run alone, the identity/birthdate/checkpoint files passed (21 runs, 0 failures), which points to
reference-data ordering. None of them exercises the JWT code.
