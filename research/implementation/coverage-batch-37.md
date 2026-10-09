# Coverage Batch 37

- Date/time: 2026-08-11
- Scope: Rails tests only; test-only changes
- Starting Rails line coverage: 47,831 / 51,307 (93.2210%)
- Ending Rails line coverage: 47,850 / 51,289 (93.2949%)
- Rails line delta: +19 covered lines, -18 relevant lines from verified dead-code removal (+0.0738
  percentage points)
- Starting Rails branch coverage: 11,151 / 15,304 (72.8633%)
- Ending Rails branch coverage: 11,169 / 15,297 (73.0143%)
- Rails branch delta: +18 covered branches, -7 relevant branches from verified dead-code removal
  (+0.1510 percentage points)

## Selected targets

- JWT issuer registry and OIDC issuer/revocation public contracts
- Social-auth link, signup, and ceremony validation boundaries
- Google OIDC nonce and stale-token rejection
- Sign-in OTP invalid-state handling

## Dead-code assessment

Verified dead code was removed from the OIDC token refactor:

- `OidcTokenExchangeCoordinator`: the old resource-type helpers had no current caller. Their only
  callers were removed when token-record issuance was replaced by token-usage issuance.
- `OidcTokenRevoker`: `find_token_by_public_id` was replaced by `find_usage_by_public_id` in the
  same refactor, with no remaining direct or dynamic caller.
- `OidcIdTokenIssuer`: `token_resource_type` had no current or historical caller.

- Base identity controllers are routed and guarded by ActionPolicy, so they are LIVE.
- Google OIDC enforcement is prepended by the OmniAuth initializer, so it is LIVE despite dynamic
  dispatch.
- OIDC token, refresh, revocation, and withdrawal services remain LIVE security or lifecycle paths
  except the verified refactor leftovers above.
- The remaining unpersisted-object, private-helper, logging-only, and configuration-rescue branches
  were retained as UNCERTAIN rather than forced through coverage tests.

## Tests added

- Verified public OIDC issuer aliases, URL derivation, revocation behavior for removed clients, and
  refresh result fields.
- Verified social-link conflict responses and social ceremony candidate validation.
- Verified Google callback nonce and ID-token freshness checks.
- Verified invalid sign-in OTP state and invalid social-signup principal rejection.

## Application and database changes

- Removed only verified dead OIDC private helpers; no live production behavior changed.

## Verification

- Narrow Rails tests for every changed component passed.
- `COVERAGE=true bin/rails test test/` generated the ending metrics above.

Vitest and other frontend coverage commands were not run because this batch is Rails-only.

## Next candidates

- Existing controller concern harnesses for observable authentication and recovery failure paths
- OIDC token exchange public endpoint behavior
- Deterministic recovery passcode and ceremony service boundaries
