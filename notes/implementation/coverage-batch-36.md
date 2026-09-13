# Coverage Batch 36

- Date/time: 2026-07-19 22:00 UTC
- Scope: Rails tests only; test-only changes
- Starting Rails line coverage: 45,614 / 49,210 (92.6925%)
- Ending Rails line coverage: 45,696 / 49,210 (92.8592%)
- Rails line delta: +82 covered lines (+0.1666 percentage points)
- Starting Rails branch coverage: 10,586 / 14,675 (72.1363%)
- Ending Rails branch coverage: 10,607 / 14,675 (72.2794%)
- Rails branch delta: +21 covered branches (+0.1431 percentage points)
- Starting failures/errors: 0 / 0
- Ending failures/errors: 0 / 0
- Remaining to 94%: 562 covered lines

## Selected targets

- `IdentitySecretCredentialCeremonyCandidateStore`
- `IdentityTotpCeremonyCandidateStore`
- `IdentityEmailCeremonyFinalCommitter`
- `IdentityTelephoneCeremonyFinalCommitter`
- `ClientSecretCredentialsUpdate`

## Tests added

- Added database-backed one-shot lifecycle, expiration, deletion, boolean normalization, and missing
  secret coverage for secret credential and TOTP ceremony candidate stores.
- Added locked-record update and app audit coverage for email and telephone ceremony final
  committers.
- Added atomic attribute normalization, persistence, and client audit coverage for secret credential
  updates.

## Application and database changes

- None.

## Dead-code evidence

- No code was deleted.

## Commands run

- `bin/rails test test/services/identity/secret_credential_ceremony_contract_test.rb test/services/identity/totp_ceremony_contract_test.rb`
- `bin/rails test test/services/identity/secret_credential_ceremony_contract_test.rb test/services/identity/totp_ceremony_contract_test.rb test/services/identity_email_ceremony_final_committer_test.rb test/services/identity_telephone_ceremony_final_committer_test.rb`
- `bin/rails test test/services/client_secret_credentials_update_test.rb`
- `COVERAGE=true bin/rails test test/`
- Read-only `jq` analysis of `coverage/coverage.json`

`vp` and Vitest commands were not run because this batch was Rails-only. RuboCop was not run because
the batch changed tests only and its known autocorrections conflict with required repository tests
and unrelated existing files.

## Skipped risky areas

- Application changes to authentication, session, OIDC, logout, token, or credential behavior
- External network access
- Destructive withdrawal behavior
- Configuration, route, fixture, factory, and database changes

## Next batch candidates

- `SocialAuthLoginHandler` (18 missed lines)
- `VisitorSecretCredentialsCreate` (15 missed lines)
- `SocialAuthLinkHandler` and `OidcTokenExchangeCoordinator` (12 missed lines each)
- `SignOtpCeremony`, `SocialAuthCoordinator`, and deterministic transaction purgers
- Controller concern branches with existing harness tests after exhausting safe service targets

`WithdrawalLifecycle` still has 34 missed lines but remains deferred because its destructive
behavior requires a higher safety threshold than the other candidates.
