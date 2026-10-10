# Identifier context retirement Red

Executed on 2026-10-10 against HEAD `651b4575746fef7346f46c37ad68eed433b58e96`, with uncommitted
application, test, migration and schema changes. Previous physical-HOTP-field slice passed both full
suites; this is a new unfinished P3d iteration, not acceptance.

Extended the public six-model absent-proof contract in `test/models/otp_failure_retention_test.rb`
to both serialized source contexts. Command:
`bundle exec rails test test/models/otp_failure_retention_test.rb -i /stored_proof_fields/`, using
RAILS_ENV/RACK_ENV=test, workers 1, owned manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, run `20261010p8b`, host `primary`, and its
complete preparation scope.

Observed exit 1: 6 runs, 56 assertions, 4 failures, zero errors/skips. Client/Visitor Email and
Telephone each fail on the still-present `sign_up_otp_context`; the two Operator models pass. These
are expected contract failures, not test-environment failures. No new migration was applied.

Read-only inventory identifies eight named source-proof triggers, four functions, source-context
CHECKs, and two registration issuer legacy-candidate guards. Preserve applied migrations and current
ceremony authority. Do not remove the legacy-candidate guard ahead of coherent source-context
retirement, and do not classify references by name alone. No dependent or unrelated feature slice
may begin before Green and the required full gate.

## Initial Green and reverse rehearsal

Rails generated `20261010232748_retire_client_identifier_otp_contexts.rb` and
`20261010232752_retire_visitor_identifier_otp_contexts.rb` in the corresponding principals migration
directories. They remove named legacy source-proof DDL only, refuse non-NULL proof before removal
under table locks, and preserve applied history. `bundle exec rails db:test:prepare` completed with
exit 0 on the same owned fleet.

Focused command selected `otp_failure_retention_test`, `enforcement_triggers_test`, Email/Telephone
credential-registration issuer tests and Email/Telephone sign-up issuer tests: 83 runs, 1,137
assertions, zero failures/errors/skips, exit 0.

Initial APP reverse rehearsal was refused by Strong Migrations at CHECK validation; the transaction
rolled back. The unchanged historical migrations remain intact. Documented and scoped the reverse
validation exception to newly recreated nullable columns whose contents are all NULL. Retried
explicit `db:migrate:down:app_zenith`/ `db:migrate:up:app_zenith` with VERSION=20261010232748, then
the matching COM tasks with VERSION=20261010232752, using fail-fast shell execution: all four
completed, exit 0. This is disposable schema-shape reversal, not recovered proof or live rollback.

Neighboring HTTP/integration tests and the new full gate are still pending; no subsequent feature
slice has begun. Current source dumps also need regeneration.

## Neighbor result and full gate started

APP/COM Email/Telephone registration controllers, APP Email sign-in security, withdrawal reentry,
Email enumeration parity and recovery-entry render tests passed: 110 runs, 770 assertions, zero
failures/errors/skips, exit 0. APP/COM schema dumps regenerated through the existing namespaced
tasks, exit 0. Full Rails and Vitest runs started; results remain pending. During startup, fixed one
lint-only long line in the Email issuer test without changing its assertions or behavior. No next
feature edit has been made.

`bun run test` finished with exit 0: 99 files, 1,140 tests, 13.42 seconds. The corrected Email
issuer test passes RuboCop; `git diff --check` passes. The full Rails test remains live; Gate 2 is
not complete until its result and regression disposition are established.

## Current catalog and document checks

A read-only Rails runner called database safety verification, then inspected the six source tables
through the public connection column/check APIs and `information_schema.triggers`. All six reported
no retired source-proof fields, no legacy context CHECKs and no legacy source-proof triggers;
exit 0. This verifies the owned fleet, not a fresh rebuild or shared/production state.

The initial `oxfmt --check` reported formatting issues in the three edited documents. Formatting was
corrected, and the repeated explicit check of `docs/checklists/contact-identifiers.md`,
`adr/email-otp-race-condition-fixes.md` and this evidence file passed with exit 0.
`git diff --check` also passed. The full Rails gate remains running; its result is not recorded as
success.

## Full regression gate result

The same full `bundle exec rails test` finished with exit 0: 15,013 runs, 127,312 assertions, zero
failures/errors/skips, 915.570830 seconds. With the current Vitest 99-file/1,140-test success above,
this passes Gate 2 for the context-retirement slice. The preceding full slice had 15,013 runs and
127,304 assertions with no failures/errors/skips; current coverage includes the strengthened
source-context absence and meaningful identity preservation assertions, rather than empty
retired-field snapshots.

Both runs used the stated HEAD plus uncommitted implementation/test/schema changes, and the
manifest-owned fleet. Only document formatting and one lint-only test line-wrap changed while the
full run was active. Fresh rebuild, a dynamic non-NULL legacy-proof refusal rehearsal, and global
acceptance remain open. This is not independent acceptance or production verification. No
application/test/schema commit or push was made.
