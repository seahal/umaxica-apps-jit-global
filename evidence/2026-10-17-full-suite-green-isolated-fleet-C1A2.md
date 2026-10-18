# Full suite green on a fresh isolated fleet after fixing a leaking concurrency test

Date: 2026-10-17 UTC. Branch: `feature`. HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`. The
worktree carries the uncommitted R1-R3 and partial R5 changes; results apply to that worktree.

## Fleet

- Existing fleet `20261016r3a1` could not run with workers: leftover worker clones were refused by
  `ParallelTestDatabaseCloner` ("preserve them for ownership review"), and
  `scripts/postgresql-rebuild-isolated-test-fleet` stopped before any drop with "role has a foreign
  or shared dependency: umaxica_com_email_hmac_definer_b0f4a9e5dd04". That fleet, its worker clones
  and roles were left untouched (user chose option A: new run ID).
- New fleets `20261017c1a1` and `20261017c1a2` were created: 32 databases each with the standard
  disposable comment, `db:test:prepare` and `db:migrate` from source, 12 HMAC roles recorded with a
  creation log in the manifest (`tmp/acceptance-isolated-<run>.json`). `20261017c1a1` was left
  polluted by the diagnosis below and is disposable.

## Finding

On `20261017c1a1`, `bin/rails test test/` with 8 workers gave 15,394 runs, 0 failures, 2 errors,
reproducible with `--seed 42061`: `ClientSecretCapacityQueryTest` fixture loading failed with
`PG::ForeignKeyViolation` on `client_emails`/`client_telephones` referencing missing `clients`.
Pairing each non-transactional test with that class on one worker identified
`test/integration/contact_registration_otp_delivery_lock_test.rb`: its `ensure` only soft-discards
the committed Client/Visitor, contact, token and ceremony rows, so a later class that reloads the
owner fixtures fails foreign-key verification. The test file's committed version has the same
cleanup, so this is a pre-existing order-dependent defect, not an R1-R5 regression.

## Change

The `ensure` block now also physically deletes the test's own ceremony transaction, contact, token,
device session and actor rows.

## Result

- The fixed file alone: 4 runs, 112 assertions, 0 failures, 0 errors.
- Fresh fleet `20261017c1a2`, `PARALLEL_WORKERS=8`, `bin/rails test test/ --seed 42061`: **15,394
  runs, 131,438 assertions, 0 failures, 0 errors, 0 skips**.
- Not run: schema drift task (known OPEN HMAC role mismatch), CI workflow (read-only path).
