# Step-up ceremony reference boundary evidence

- Date: 2026-10-12
- Repository: `/home/global/workspace`
- Branch: `feature`
- Tested HEAD before this documentation update: `35408d8889f3fdb5775d4ec010bbc8637de2d9c8`
- Worktree: already contained unrelated and earlier implementation changes; the Step-up
  implementation and test changes were uncommitted during these checks. No existing changes were
  reset, stashed, discarded or included by inference.

## Scope

This record covers only the generated `transaction_id` and `grant_jti` boundary of
`StepUpCeremonyTransactionable.create_transaction!`. It does not establish acceptance for
`result_jti`, proof/authenticator values, session issuance, database-level identifier immutability,
external providers, production deployment or the independent acceptance investigation.

## Checks performed

1. A focused Red run of `test/services/identity/step_up_ceremony_acme_transaction_test.rb`
   reproduced the former UUID generation and missing collision retry:
   `6 runs, 33 assertions, 3 failures, 0 errors, 0 skips`.
2. After the smallest implementation change, the focused Green run of the same file passed:
   `6 runs, 41 assertions, 0 failures, 0 errors, 0 skips`.
3. The related Step-up collection was run with the run-owned twenty-database manifest
   `tmp/acceptance-isolated-20261010p8b-primary.json`, four workers, and explicit test-only database
   names. The 19 named files passed `204 runs, 1758 assertions, 0 failures, 0 errors, 0 skips`.
4. Targeted RuboCop passed for `app/models/concerns/step_up_ceremony_transactionable.rb` and
   `test/services/identity/step_up_ceremony_acme_transaction_test.rb` with no offenses.
5. The Rails Gate 2 command was the repository's full `bundle exec rails test` under the same
   run-owned test manifest and four workers. It passed
   `15184 runs, 128457 assertions, 0 failures, 0 errors, 0 skips`.
6. The Vitest Gate 2 command `bun run test` passed `99 files` and `1140 tests`.

The Rails run emitted existing Flipper and OmniAuth diagnostic output; it did not produce test
failures. No CI, Podman, production database, external provider, shared destructive operation or
remote synchronization was used. This evidence is a record of the listed revision and execution
environment, not a permanent PASS for later code.
