# Entra ORG sign-in production hardening (four fixes)

Continuation of an interrupted session. The four items were audited against the `feature` branch at
`080cee6df` (which already contains `1e30e207f`), then implemented.

## State found

| Item | State at audit |
| --- | --- |
| 1. Boot fail-fast for the three Entra credentials | partial — only `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET` was required at boot |
| 2. `client_secret_post` at the token endpoint | missing — `client_auth_method: :basic` |
| 3. Fail-closed provider x host matrix | missing — unknown hosts fell back to `:app` |
| 4. Rate limit on `/social/entra/failure` | missing — only `:omniauth` was limited |

The two-stage Normal sign-in (Entra -> pending transaction -> passkey/secret -> session) was already
present and was not modified.

## Resolved gem versions (checked in Gemfile.lock)

`omniauth_openid_connect 0.8.0`, `openid_connect 2.5.0`, `rack-oauth2 2.3.0`. In rack-oauth2 2.3.0,
`Client#authenticated_context_from` has no named branch for `client_secret_post`, so that value
reaches the `else` that merges `client_id`/`client_secret` into the POST body and sets no
`Authorization` header.

## Blocker cleared first

`bin/rails test` could not boot: the untracked in-progress architecture-cop work places
`lib/rubocop/cop/umaxica/*.rb` inside `config.autoload_lib`, and those files subclass
`RuboCop::Cop::Base`, which does not exist under the application. Added `rubocop` to the
`autoload_lib(ignore:)` list. Also `test_primary_db` did not exist; it was created by
`RAILS_ENV=test bin/rails db:prepare` (the `platform` -> `primary` change had not been rebuilt).

## Test evidence

All runs inside the `global-devcontainer-core` container.

| Command | Result |
| --- | --- |
| `bin/rails test test/lib/entra_omniauth_boot_credentials_test.rb` | 11 runs, 61 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/contracts/omniauth_entra_token_request_contract_test.rb` | 4 runs, 18 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/initializers/omniauth_social_provider_host_matrix_test.rb` | 9 runs, 113 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb` | 21 runs, 68 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/tooling/primary_database_ownership_test.rb` | 4 runs, 22 assertions, 0 failures, 0 errors, 0 skips |
| Entra/external-auth focused set (11 paths) | 232 runs, 1988 assertions, 0 failures, 0 errors, 0 skips |

`RAILS_ENV=test bin/rails db:prepare` created `test_primary_db` and applied
`20260807000000 CreateFlipperTables` from `db/migrate`. `bin/rails db:prepare` (development,
`POSTGRESQL_PRIMARY_PUB=primary`) exited 0.

`bin/rubocop --cache false` over the ten changed Ruby files: no offenses.

Two failures were found and fixed during the run, both caused by work in this session:

- `PrimaryDatabaseOwnershipTest` asserted the literal `test_primary_db`, which fails under
  parallel workers (`test_primary_db_4`). Relaxed to the base name plus optional worker suffix.
- `OmniauthCallbacksTest#test_should_sign_in_with_existing_Google_user` broke under the first
  fail-closed host matrix: `config/routes/base.rb` mounts `/social/authentication/completion` and
  the app-surface provider callbacks on the **base** service host, not only the auth host. The app
  branch now covers both hosts, mirroring the com branch, and the matrix test covers both.

## No network in the suite

The token-request contract test drives the real `Rack::OAuth2::Client` with `Rack::OAuth2.http_client`
stubbed to raise after capturing the request, so no request reaches `login.microsoftonline.com`.
Boot-time credential validation is presence and shape only; a test stubs `Net::HTTP.start` to fail
the run if boot validation performs network I/O.

## Full suite

`bin/rails test`: **12919 runs, 78628 assertions, 1 failures, 8 errors, 2 skips**.

All nine are in the com sign-up / visitor identity surface and none touch Entra, OmniAuth, external
authentication, or the `primary` database:

- `Auth::Com::Sign::Up::Check::Email::BirthdatesControllerTest#test_clearing_the_birthdate_completes_the_com_sign-up`
- `Auth::Com::Sign::Up::Check::Telephone::CheckpointFlowTest#test_the_passcode_checkpoint_clears_its_requirement_and_advances_to_the_birthdate_step`
- `AuthComUpCheckpointTelephoneControllerTest` (5 tests)
- `BaseIdentityCredentialManagementTest#test_com_secret_credential_removal_discards_the_credential_when_another_remains`
- `IdentitySettingsPageCoverageTest#test_visitor_browses_identity_secrets_and_email_registration_failure_paths`

They fail with `PG::ForeignKeyViolation` on `visitor_passkeys.status_id` /
`visitor_secret_credentials.visitor_secret_credential_status_id`, and one status-presence validation
error.

Causation was established, not assumed. These belong to a **separate, unrelated in-progress work
stream** present uncommitted in the worktree (the architecture-cop / method-visibility harness:
`lib/rubocop/`, `.rubocop_todo.yml`, `docs/architecture/method-visibility-and-concerns.md`, and
modifications to `app/models/{client,operator,visitor}.rb` and `app/models/concerns/identity.rb`
that replace the `included do ... end` validation hook with per-class declarations). Reverting only
those four model files to `HEAD` makes
`test/controllers/auth/com/sign/up/check/email/birthdates_controller_test.rb` pass (2 runs, 13
assertions, 0 failures, 0 errors); restoring them reproduces the failure. Those files were then
restored unchanged — that work stream is out of scope here and was preserved, not modified.

The only file from that stream this session touched is `config/application.rb`, and only to stop
`lib/rubocop/` from being autoloaded into the application, which was preventing the suite from
booting at all.
