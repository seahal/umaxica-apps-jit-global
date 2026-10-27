# A-9: hand-run sign-up diagnosis removed (D-196)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with extensive uncommitted cycle
  changes.
- Deleted: `app/queries/sign_up_attempt_diagnosis_inventory.rb`, `lib/tasks/sign_up_diagnosis.rake`,
  `test/queries/sign_up_attempt_diagnosis_inventory_test.rb`.
- `Valkey::AuthState::OpaqueAdmissionStore.reference_digest` was public only for the deleted query;
  the digest is inline in `reference_storage_key` again (pre-WU-26 form) and its test was removed.
- Docs: `docs/operations/stuck-sign-up-registration-runbook.md` no longer contains `bin/rails runner`
  commands or the manual `SignUpArtifactCleanup.call`; it describes reading the automatic WU-38 event
  and escalating. `docs/security/sign-up-sequence.md` and `adr/sign-up-finalization-in-auth.md`
  updated. `three.md` A26-1/A26-2 marked "Withdrawn (D-196)". `rg` finds no remaining reference.
- Incident during the check: the owner's `bin/rails db:migrate:reset` (development) rewrote 33
  `db/*_structure.sql` files almost empty (82,741 lines removed). With owner approval:
  `bin/rails db:schema:dump` restored them from the migrated development databases; the remaining
  diff against HEAD is only this cycle's four uncommitted drop migrations. The test databases were
  then rebuilt by the owner with the R6V2 procedure (`RAILS_ENV=test db:drop db:create` plus
  per-pool `migrate`); `db:test:prepare` alone had left fixture loads failing with an
  `avatars.lifecycle_state_id` foreign-key violation.
- `PARALLEL_WORKERS=1 bin/rails test` on the Valkey store test and the WU-38 / retention tests
  (`rg -l 'SignUpStuckRegistration|stuck_registrations|RetentionPurgeJob' test`): 81 runs,
  820 assertions, 0 failures, 0 errors. RuboCop: no offenses on the changed Ruby files.
