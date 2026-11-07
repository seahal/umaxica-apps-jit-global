# Rails test groups A, B, C — repair and verification

## Scope

Test-side repair only (`test/**`) of three groups of failing Minitest cases. No `app/`, `lib/`,
`config/` or `db/` file was edited by this work. Group D (step-up/passkey/TOTP/registration-
committers) was left alone.

## Commits and worktree

- `git rev-parse HEAD` at the final run: `f56c805bc3dfbf5d22fb6eb27d0b4490eedf05ec`
- Baseline run commit (2026-11-03): `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`
- HEAD moved during the session (`efdcd80d3` → `b30345216` → `f56c805b`) as other work landed, and
  the worktree was dirty throughout with unrelated staged/unstaged changes. The counts below are
  therefore not a like-for-like comparison with the baseline: the suite grew from 16741 to 16901
  cases and the production code changed between the two runs.
- Dirty files at hand-off: `test/models/app_preference_chronicle_test.rb`,
  `test/support/database_selector_primary.rb`, `test/support/sign_up_journey_cleanup.rb` (this
  session) plus `specs/browser-flow-state-cookies/{inventory,spec}.md` (unrelated).

## Commands and counts

| Run | Command | Result |
| --- | --- | --- |
| Baseline (2026-11-03) | `bin/rails test` | 16741 runs, 248 failures, 643 errors, 0 skips |
| First verification | `bin/rails test` @ `b30345216` | 16901 runs, 305 failures, 129 errors, 0 skips |
| Final verification | `bin/rails test` @ `f56c805bc` | **16901 runs, 145611 assertions, 304 failures, 129 errors, 0 skips** |
| Narrow (all repaired files) | `PARALLEL_WORKERS=1 bin/rails test <15 files>` | 282 runs, 3794 assertions, 1 failure, 0 errors |
| Style | `bin/rubocop <18 changed files>` | 18 files inspected, no offenses detected |

Total failing cases fell from 891 (248F + 643E) to 433 (304F + 129E). 157 distinct test files still
fail; none of them are repaired files except the two listed under "Not fixed" below.

## Group A — fixture-load foreign-key cascade (FIXED)

Root cause, confirmed empirically: `ActiveRecord::FixtureSet.insert` → `insert_fixtures_set` wraps
the load in `disable_referential_integrity`, and re-enabling the constraint runs
`ALTER TABLE ... ENFORCED`, which validates every existing row. A rolled-back probe on
`test_app_zenith_db` reproduced the mechanism (`insert or update on ... violates foreign key`
raised only by the re-enable, not by the insert). Orphan rows in non-fixture app_zenith tables
referencing synthetic clients therefore aborted the load for every later fixture-loading case in
that worker.

Causal chain: polluters leaked committed flows, resolutions and secret-sign-in references into
`op_base_app`; a victim's teardown then ran
`ClientSignInFlow.where(principal_id: owner_ids).delete_all`, matched the leaked rows through a
recycled synthetic principal id, aborted on `ON DELETE RESTRICT`, leaked its own
completion/account/lock rows, and the next fixture load failed validation.

Changes (all `test/**`):

- `test/support/sign_in_flow_cleanup.rb` (new) — `SignInFlowCleanup#delete_client_sign_in_flows!`
  deletes session-limit resolutions, secret sign-in receipts and the OIDC secret-flow reference
  before the flows themselves.
- `test/support/sign_up_journey_cleanup.rb` (new) — `SignUpJourneyCleanup` watermark capture and
  FK-ordered deletion for whole sign-up journeys (used by Group B).
- Polluters given watermarked setup/teardown: `session_limit_resolution_transactionable_test.rb`,
  `client_secret_resolution_concurrency_test.rb`, `email_sign_in_flow_isolation_test.rb`. Each now
  measures `NO LEAK` with `tmp/opencode/count_all.sh` (row counts over
  `test_app_zenith_db test_op_base_app_db test_op_base_org_db test_org_zenith_db test_chronicle_db`
  before and after a run).
- Five victim teardowns hardened with `include SignInFlowCleanup`:
  `contact_email_signup_source_audit_test.rb`, `email_signup_base_root_completion_test.rb`,
  `email/birthdates_controller_test.rb`, `email/otps_controller_test.rb`,
  `in/secrets_controller_test.rb`.

Verified: all nine Group A files report 0 failures in the final full run.

## Group B — transactional fixtures starve the OTP delivery issuer (FIXED, one exception)

Root cause: `EmailSignUpOtpDeliveryIssuer` / `TelephoneSignUpOtpDeliveryIssuer` raise
`DeliveryUnavailable` while any Source or Ticket transaction is open. With the default
`use_transactional_tests = true` the fixture transaction is always open, so every delivery became
a 503 and the follow-up request had a `nil` location.

The shared fix is `self.use_transactional_tests = false` plus `self.fixture_table_names = []` (or
an explicit fixture list) plus watermark capture in `setup` and `SignUpJourneyCleanup` deletion in
`teardown`. `test/support/sign_up_journey_cleanup.rb` carries the FK-safe order: ceremony
transactions → sign-up flows → admission bindings → ceremony sessions → session-limit resolutions
→ OIDC parents → sign-in flows → tokens before device sessions → owner-scoped records → clients →
chronicles.

A second, independent defect surfaced during this work: Rails' `DatabaseSelector` sends a read to
the replica once `Time.now - session[:last_write] >= delay` (10s). A test that travels the clock
looks stale immediately, and a session with no prior write defaults its timestamp to the epoch and
*always* looks stale. The test environment's replica databases are static copies that never
receive a test's committed rows, so such a read cannot see them. `test/support/database_selector_primary.rb`
(new) prepends `FreshLastWrite` to `Resolver::Session` while a test sets `keep_reads_on_primary!`
in setup and `restore_database_selector_delay!` in teardown. Four files opt in.

Files: `state_machine_test.rb` (separate cause — new `with_cycle_lock` locks
`Client.find(principal_id)` but the test hardcoded `principal_id: 123`; now creates a real
`Client`), `sign_up_phase_regression_app_test.rb`, `telephone/otps_controller_test.rb`,
`emails_controller_test.rb`, `telephones_controller_test.rb`,
`checkpoint_passkeys_controller_test.rb`.

Verified: five of the six files report 0 failures in the final full run.

## Group C — preference tests (PARTIALLY FIXED)

- `test/models/preference_public_id_collision_test.rb` and
  `test/models/concerns/preference/resettable_test.rb` already pass.
- `test/models/app_preference_chronicle_test.rb` — **fixed**. The case expected
  `ActiveRecord::NotNullViolation` from `save!(validate: false)`, but the uncommitted
  `before_create :coordinate_preference_reference!` guard in `app/models/app_preference_chronicle.rb`
  resolves an `AppPreference` subject before the statement runs and raises
  `ActiveRecord::RecordNotFound` first. The case now points the audit at a subject type the guard
  does not resolve, keeping the original NOT NULL assertion unchanged. 8 runs, 0 failures.

## Not fixed, and why

1. `test/controllers/auth/app/up/emails_controller_test.rb` —
   `test_email_signup_checkpoint_cancel_stops_the_signup_path` (1 failure in the final run).
   The case asserts `assert_redirected_to auth_app_sign_up_url(ri: "jp")`, but the uncommitted
   `sign_entry_parent_cancellation` / `redirect_to_sign_entry_parent_cancellation!` in
   `app/controllers/concerns/sign_entry_exit.rb` now hands a sign-up that belongs to an OIDC
   parent back to the parent (`https://jump.umaxica.net/?rt=...`, observed 303). The case never
   reached that assertion before this work — it died earlier on the 503. Deciding whether the jump
   handoff is the intended contract is a production decision, not a test repair, so the assertion
   was left unchanged.

2. `test/contracts/openapi_preferences_contract_test.rb` — 8 failures. Two distinct causes, both
   code/contract conflicts rather than test defects:
   - `PreferenceBrowserControlsRegistry::MATRIX` (committed) declares browser preference *writes*
     only for `base`; `auth`, `core` and `warp` return `403 urn:umaxica:problem:authorization-denied`
     from `require_preference_browser_writer!`. The case still expects `200`/`204` for those
     families.
   - `anonymous_preference_claim_shape?` in `app/controllers/concerns/preference_base.rb` returns
     true for `AppPreference`, `ComPreference` *and* `OrgPreference`, so
     `PATCH /api/v0/preferences/cookie` always answers `200 {"cookie":{...}}`. The committed
     description `openapi/app/paths/preferences-cookie.yml` declares `204` for that operation, and
     the case asserts `:no_content`. Implementation and description disagree at HEAD; changing the
     case would silently pick a side.

## Discrepancies found

- `test/test_helper.rb:398` `create_base_rp_test_session` exceeds `Metrics/MethodLength`
  (46/45). Pre-existing: the same offense is reported when RuboCop runs against the HEAD version
  of the file. Not introduced by this work and not touched by it.
- `app/controllers/concerns/preference_base.rb` (implementation) vs
  `openapi/app/paths/preferences-cookie.yml` (committed description) disagree on the status and
  body of `PATCH /api/v0/preferences/cookie` on the app and org surfaces — see "Not fixed" 2.
- The 2026-11-03 baseline's `test_app_zenith_db_0..15` clone pollution (79 rows referencing
  synthetic clients) and the 25 `client_chronicles` rows orphaned by `client_chronicle_events`
  event id 36 no longer exist: the databases were rebuilt after HEAD moved past `b30345216`
  (schema stamp changed, so `ParallelTestDatabaseCloner` re-cloned). The blocker that previously
  produced `583 runs, 583 errors` on a polluted clone is gone, and no database rows were deleted
  by this session.

## Unverified / out of scope

- Group D was not touched, as instructed.
- `bin/rails test:system`, `bun run test`, `bin/brakeman` and `bin/ci` were not run; only the Ruby
  suite and `bin/rubocop` cover the changed files.
