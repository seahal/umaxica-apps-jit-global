# OP-mediated step-up follow-up

Date: 2026-11-04

Full HEAD: `b30345216886c98af1f04cbd434f067f12decf01`

Worktree: extensively modified before and during this work; results are from the current local
worktree and do not describe a clean checkout.

## Verification

- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/base_rp_contact_registration_refusal_test.rb`:
  **2 runs, 36 assertions, 0 failures, 0 errors** after removing the exact test-created passkey
  residue described below. Its first attempt was blocked by fixture foreign-key validation.
- Focused lock-order command covering `sign_up_secret_lock_order_test`,
  `step_up_email_lock_order_test`, `sign_up_artifact_cleanup_atomicity_test`,
  `sign_up_artifact_cleanup_test`, and `session_limit_resolution_transactionable_test`: **37 runs,
  200 assertions, 0 failures, 0 errors** after the same cleanup. The first attempt failed during
  fixture setup with 36 errors.
- Focused Q-1 HTTP selection from `step_up_authentication_test.rb`: **3 runs, 11 assertions, 1
  failure**. Expired evidence and revoked-root refusal pass. The valid-event downgrade still returns
  422 instead of redirecting. A temporary TracePoint inspection observed a valid cell-process
  AccessState with no `BrowserSessionSecurityContext`; `current_session_token` is nil and the
  controller refuses before the evidence verifier.
- `test/operations/identity_passkey_name_committer_test.rb`: **14 runs, 87 assertions, 0 failures, 0
  errors**.
- `test/operations/identity_credential_removal_committer_test.rb`: **16 runs, 172 assertions, 0
  failures, 0 errors**.
- Focused passkey APP/ORG HTTP regression: **1 run, 12 assertions, 1 failure**. Rename returns 303;
  the subsequent passkey deletion returns 422.
- `bundle exec rubocop app/operations/identity_passkey_name_committer.rb test/operations/identity_passkey_name_committer_test.rb test/integration/base_passkey_mutation_step_up_test.rb test/integration/step_up_authentication_test.rb`:
  **4 files inspected, no offenses**.
- Scoped `git diff --check -- test/integration/step_up_authentication_test.rb`: passed.
  Whole-worktree `git diff --check` reports pre-existing trailing blank lines at `AGENTS.md:187` and
  `adr/rails-routing-resourceful-policy.md:196`; neither file was changed in this work.
- Route and runtime-role search found no `sensitive_admission` declarations. The O-9 Visa endpoints
  remain disconnected.

## Exact test database cleanup

In `test_app_zenith_db`, removed only `ClientPasskey` ID `652` for fixture Client ID `980190986`.
The row timestamp was `2026-11-04T16:42:13.370385Z`; the fixture Client was created in the same
second. There is no `test/fixtures/client_passkeys.yml` and no matching passkey audit outbox row.
The Client and its older OIDC connection were retained. A later read-only check found zero passkey
rows and zero orphan passkey rows in that test database.

The Q-1 valid-event refusal and public passkey removal failure remain implementation blockers for
the owner-side O-10 boundary. The global lock-order inventory also remains incomplete.
