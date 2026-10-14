# Passkey slot concurrency follow-up on the standard test database

Work was performed against full HEAD `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5` on branch
`feature`. The worktree was extensively dirty; the concurrency test change and the other uncommitted
work affected verification. `one.md` and `two.md` remain unchanged at SHA-256
`663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c` and
`7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.

The Step 20 full Rails run had reported a Passkey-slot concurrency assertion failure that passed
when selected alone. Running the entire `AuthCeremonyRevocationConcurrencyTest` file on the standard
test databases exposed a COM cleanup foreign-key error: the test created a Visitor with a sequential
ID, and the database had a `visitor_passkeys` row referencing that ID. The deletion failed at the
test's `ensure` cleanup. The test code in this path does not create a Passkey; the ID collision is
the inferred cause, supported by the FK failure and by its slot-count query.

The COM actor in that test now uses the file's existing `create_unique_visitor!` helper, which other
COM concurrency cases in the same file already use. The selected case passed with 1 run / 36
assertions. The full file passed with 18 runs / 269 assertions. RuboCop inspected the file with no
offenses, and `git diff --check` passed.

The prescribed full command was rerun:

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test
```

It used the standard Rails `test_*` database manifest and finished with 15,256 runs, 128,994
assertions, 0 failures, 14 errors and 0 skips. All 14 errors came from Avatar committed-history
tests refused by `ParallelTestDatabaseCloner.verify_owned_worker_execution!` because the run had no
run-owned worker receipt. They were in Avatar reservation, concrete ownership period, ownership
transfer concurrency, moniker concurrency and retention-purge cases. No Strict Loading errors
appeared in the run.

The earlier non-transactional class run failed during cleanup after the foreign-key refusal, leaving
its test-created Visitor at the colliding ID. The referenced Passkey row's prior ownership was not
established and it was not removed. No manual cleanup was performed. No isolated database, reset,
migration command, or receipt-guard bypass was used. The full Rails suite remains non-clean, so
Steps 19–20 and final acceptance remain open.
