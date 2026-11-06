# WU-A3 explicit state shape recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 548 modified tracked paths and 267 untracked paths, with no staged paths. Existing changes were
preserved; no commit was created.

The owner approved the App/Org Auth Ceremony and OIDC parent shapes and local development/test
migrations. Read-only migration-status checks confirmed the related Auth Ceremony and OIDC
migrations were already `up` in Development and Test App/Org. No migration was applied or rerun in
this check. Development and Test are the only databases involved; production and Neon were not
accessed. The prior cutover evidence is
`evidence/2026-11-01-wua3-coupled-status-local-cutover-C7N5.md`.

Read-only schema checks found, in all four local databases, NOT NULL ceremony/OIDC `status_id`
columns, validated foreign keys to reference tables, the approved reference IDs (8 Ceremony and 4
OIDC values per realm), and no persisted OIDC text `status` column. Development had zero rows in all
four tables. After the focused tests below, Test App contained 478 Ceremony rows and 91 OIDC parent
rows; Test Org contained 41 Ceremony rows and zero OIDC parent rows. All Test rows used the
referenced status IDs. The focused tests added rows to the Test databases; the rows were left in
place and were not deleted.

An exploratory check recalculated the migration's original status mapping from current Ceremony
facts and found 170 App and 21 Org `replaced` rows whose old predecessor pointer was no longer
present. This is not evidence that the backfill misclassified those rows:
`AuthCeremonySession#rotate!` updates `previous_sid_digest` during in-place SID rotation, while the
new `status_id` is the authoritative lifecycle state. The migration's one-time mapping is not a
valid ongoing invariant after those mutable SID-generation facts change.

The first six-file focused run reached 61 tests and 423 assertions, then reported 16 fixture-load
errors before affected test bodies ran. The errors came from unrelated orphaned global fixtures. The
OIDC coordinator service test now disables unrelated fixtures and creates its needed active Client
directly. The Cancel URL test and lifecycle state-write guard disable fixtures because they do not
use database fixtures. The corrected selection passed:

`bin/rails test test/models/auth_ceremony_session_test.rb test/models/auth_ceremony_session_concurrency_test.rb test/models/concerns/oidc_authorization_transactionable_test.rb test/services/oidc_authorization_transaction_service_test.rb test/services/oidc/authorization_cancel_state_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`

Result: 61 runs, 533 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop on the three changed
test files, Ruby syntax checks, and `git diff --check` passed.

This recheck does not close WU-A3 or `two.md`. The ORG Switch statement still conflicts with the
accepted sign-up contract; the related owner direction and shared AC-40/50/51 acceptance remain
open. No full test suite was run.
