# Sign-in sequence issuer slice

- Date: 2026-10-12
- Code revision under test: `4c4d2eeb8e77dd727b36fd3d2bfbf407da88d71d`
- Working tree: 48 pre-existing or implementation-owned modified/untracked paths; the sequence
  source and test were intentionally left uncommitted. No unrelated path was reset, cleaned or
  staged.
- Scope: replace only new `SignInSequenceCarrier` session workflow IDs with the shared
  `PublicId.generate` issuer. Existing UUID-valued serialized sessions remain readable. No
  migration, database write, raw SQL, provider-secret, CI, Podman, production or shared destructive
  operation was used.

## TDD and verification

- Red, before the production edit:
  `RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres POSTGRESQL_TEST_PREPARE_DATABASES=<manifest databases> bundle exec rails test test/services/sign_in/sequence_carrier_test.rb`
  Result: `9 runs, 29 assertions, 1 failures, 0 errors, 0 skips`; the failure was the expected UUID
  value not matching the NanoID-21 contract.
- Green focused collection:
  `test/services/sign_in/sequence_carrier_test.rb test/policies/sign_in_sequence_policy_test.rb test/controllers/auth/org/in/checkpoints_controller_test.rb test/controllers/auth/com/in/checkpoints_controller_test.rb`
  Result: `29 runs, 68 assertions, 0 failures, 0 errors, 0 skips`.
- Targeted RuboCop:
  `bundle exec rubocop app/services/sign_in_sequence_carrier.rb test/services/sign_in/sequence_carrier_test.rb`
  Result: no offenses.
- Rails Gate 2, run-owned twenty-database manifest with four workers:
  `15146 runs, 128238 assertions, 0 failures, 0 errors, 0 skips`.
- Vitest Gate 2 using the same manifest scope: `99 files, 1140 tests, 0 failures`.
- `git diff --check`: passed.

These results are implementation evidence for this dirty worktree, not an independent acceptance
decision. Host Alloy recreation/runtime verification, D-11 committed-transaction isolation,
operational Avatar cutover, retained legacy identifier semantics, privacy-retention policy and the
user-excluded independent acceptance work remain outside this slice.
