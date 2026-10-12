# APP TOTP enrollment transaction-reference issuer evidence

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

HEAD used for the checks: `816c31dba7bf3d084fbe8a0a7cd652c49d015c8b`

Worktree: dirty before and during the checks; unrelated staged, unstaged and untracked changes were
preserved.

## Scope

This slice changes only the APP TOTP enrollment child transaction `transaction_id` issuer and its
transaction factory input. New child transaction references use `PublicId.generate` (NanoID-21). The
step-up parent reference, grant JTI, OTP proof, candidate reference and result identities remain
unchanged. Collision retries are limited to the named child transaction `transaction_id` unique
B-tree index and execute in a database savepoint.

## Verification

All Rails commands used the run-owned manifest `tmp/acceptance-isolated-20261010p8b-primary.json`,
PostgreSQL host `10.89.2.3/32:5432`, and its twenty databases. No CI, Podman, production or shared
destructive operation was used.

- Red, before the production change, using the focused issuer file —
  `3 runs, 25 assertions, 1 failure, 0 errors, 0 skips`; the failure was the expected former UUID
  child reference.
- Focused issuer collection after the implementation and named collision test —
  `4 runs, 32 assertions, 0 failures, 0 errors, 0 skips`.
- TOTP regression collection, restricted to `.rb` files —
  `173 runs, 1380 assertions, 0 failures, 0 errors, 0 skips`.
- Rails Gate 2, four workers — `15151 runs, 128275 assertions, 0 failures, 0 errors, 0 skips`.
- Vitest (`bun run test`) — `99 files passed, 1140 tests passed`.
- Targeted RuboCop over the changed concern, issuer and test — no offenses.
- `git diff --check` — passed for tracked documentation changes; the untracked evidence file was
  separately checked for whitespace before staging.

The first broad TOTP command included a fixture YAML and Rails rejected it before loading tests;
that invocation is not counted as a test result. The corrected collection used only `.rb` files. The
full gate emitted existing Flipper/OmniAuth/constant-reinitialization diagnostics during unrelated
tests; no failure or error resulted. This evidence does not establish the remaining TOTP-purpose
matrix, other ceremony identifiers, D-11 committed-transaction isolation, production behavior or
independent acceptance.
