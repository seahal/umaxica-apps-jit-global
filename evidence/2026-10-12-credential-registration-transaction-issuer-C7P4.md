# Credential-registration transaction-reference issuer evidence

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

HEAD used for the checks: `78d2ad5051c0adc7879954843ac2d65290f2de1d` Worktree: dirty before and
during the checks; unrelated staged, unstaged and untracked changes were preserved.

## Scope

This slice changes only the six concrete Email/Telephone credential-registration transaction issuers
and their session/delivery binding readers. New transaction references use `PublicId.generate`
(NanoID-21). Existing UUID-v4 references remain readable. OTP generation remains a separate UUID-v4
one-time identity. Collision retries are limited to the named concrete `transaction_id` unique
B-tree index and execute in a database savepoint.

## Verification

All Rails commands used the run-owned manifest `tmp/acceptance-isolated-20261010p8b-primary.json`,
PostgreSQL host `10.89.2.3/32:5432`, and the twenty databases named by that manifest. No CI, Podman,
production or shared destructive operation was used.

- Red, before the production change, with the correctly configured run-owned test environment:
  `bundle exec rails test` over the six focused issuer/value files —
  `33 runs, 488 assertions, 8 failures, 3 errors, 0 skips`. The failures were the expected former
  UUID issuers and rejected NanoID references.
- Focused Green collection:
  `bundle exec rails test test/operations/contact_registration_otp_issuer_test.rb test/operations/email_credential_registration_otp_issuer_test.rb test/operations/telephone_credential_registration_otp_issuer_test.rb test/values/credential_registration_otp_session_value_test.rb test/values/contact_registration_otp_delivery_binding_value_test.rb test/values/email_credential_registration_otp_delivery_binding_value_test.rb`
  — `35 runs, 729 assertions, 0 failures, 0 errors, 0 skips`.
- Broader credential-registration collection selected by filename —
  `531 runs, 8643 assertions, 0 failures, 0 errors, 0 skips`.
- Rails Gate 2, four workers — `15150 runs, 128278 assertions, 0 failures, 0 errors, 0 skips`.
- Vitest (`bun run test`) — `99 files passed, 1140 tests passed`.
- Targeted RuboCop over the eleven changed Ruby implementation/test files — no offenses.
- `git diff --check` — passed after the documentation and evidence edits.

The Rails suite emitted existing Flipper/OmniAuth/constant-reinitialization diagnostics during
unrelated tests; no test failure or error resulted. This evidence does not establish the remaining
unclassified ceremony transaction/grant/result purpose matrix, D-11 committed-transaction isolation,
production behavior or independent acceptance.
