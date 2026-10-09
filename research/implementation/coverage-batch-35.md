# Coverage Batch 35

- Date/time: 2026-07-19 21:35 UTC
- Scope: Rails tests only; test-only changes
- Starting Rails line coverage: 45,581 / 49,210 (92.6255%)
- Ending Rails line coverage: 45,614 / 49,210 (92.6925%)
- Rails line delta: +33 covered lines (+0.0671 percentage points)
- Starting Rails branch coverage: 10,571 / 14,675 (72.0341%)
- Ending Rails branch coverage: 10,586 / 14,675 (72.1363%)
- Rails branch delta: +15 covered branches (+0.1022 percentage points)
- Starting failures/errors: 0 / 0
- Ending failures/errors: 0 / 0
- Remaining to 94%: 644 covered lines

## Selected targets

- `CommonRedirect` malformed safe-jump URL handling and priority resolver failure logging
- `Oidc::AcmeServiceOrigin` decision predicates and malformed URL handling
- `IdentityPasskeyCeremonyContract` timestamp, navigation metadata, and malformed token validation
- `SecurityJwtAuthAccessTokenCodec` payload mismatch, claim extraction, scope checks, and issuer
  inference
- `JumpRtReturnVerifier` bounded JWKS response parsing and normalized fetch failures

## Tests added

- Added malformed URL and resolver failure coverage to `test/controllers/concerns/redirect_test.rb`.
- Added decision predicate and malformed origin coverage to
  `test/services/oidc/acme_service_origin_test.rb`.
- Added direct contract validation coverage to
  `test/services/identity/passkey_ceremony_contract_test.rb`.
- Added claim helper, payload mismatch, and issuer inference coverage to
  `test/services/security_jwt_auth_access_token_codec_coverage_test.rb`.
- Added network-free JWKS success and failure tests to
  `test/services/jump_rt/return_verifier_test.rb`.

## Application and database changes

- None.

## Dead-code evidence

- No code was deleted.

## Commands run

- `bin/rails test test/controllers/concerns/redirect_test.rb test/services/oidc/acme_service_origin_test.rb test/services/identity/passkey_ceremony_contract_test.rb`
- `bin/rails test test/controllers/concerns/redirect_test.rb test/services/oidc/acme_service_origin_test.rb test/services/identity/passkey_ceremony_contract_test.rb test/services/security_jwt_auth_access_token_codec_coverage_test.rb`
- `bin/rails test test/services/jump_rt/return_verifier_test.rb`
- `COVERAGE=true bin/rails test test/`
- Read-only `jq` analysis of `coverage/coverage.json`

`vp` and Vitest commands were not run because this batch was Rails-only. RuboCop was not run because
the batch changed tests only and its known autocorrections conflict with required repository tests
and unrelated existing files.

## Skipped risky areas

- Authentication, session, OIDC token, logout, credential, and destructive lifecycle implementation
  changes
- External network access; JWKS HTTP behavior was exercised with an in-process stub
- Controller-heavy targets requiring broad workflow setup
- Application, database, configuration, route, fixture, and factory changes

## Next batch candidates

- `IdentitySecretCredentialCeremonyCandidateStore` (21 missed lines)
- `IdentityEmailCeremonyFinalCommitter` (20 missed lines)
- `IdentityTotpCeremonyCandidateStore` (19 missed lines)
- `ClientSecretCredentialsUpdate` (19 missed lines)
- Deterministic transaction purgers and `OidcTokenRevoker` after confirming their tests isolate side
  effects

`WithdrawalLifecycle` has 34 missed lines but remains lower priority because withdrawal behavior is
destructive and requires a higher safety threshold than the candidate stores and pure validation
paths.
