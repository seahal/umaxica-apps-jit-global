# Public identifier update boundary

Verified on 2026-10-10 against commit
`2a1644f73238839ed7ed513bd4681ea393a86682` with the working tree containing unrelated
uncommitted application, migration, documentation, test, and evidence changes. No reset,
stash, commit, push, production database, shared database reset, CI, or external service was used.

## Delivered slice

- `PublicId` now rejects changing a persisted `public_id` through the ordinary Active Record
  validation/save boundary. Creation-time generation and explicitly supplied creation values remain
  available to their existing callers.
- The public-ID contract test covers the rejection and confirms that the persisted value remains
  unchanged.
- Existing tests that used to mutate a persisted public ID merely to test uniqueness or length now
  create a separate record for the duplicate case, or assert the new immutable-update contract.
- Avatar purge deferral coverage now includes two independent connections recording the same
  Avatar/reason concurrently and converging on one row with both observations retained.

## Checks

- Focused Rails command with isolated manifest `20261010p8b`, host `primary`, and
  `PARALLEL_WORKERS=1`:
  `bundle exec rails test test/models/concerns/public_id_test.rb test/models/client_test.rb test/models/avatar_agent_binding_test.rb test/models/avatar_individual_binding_test.rb test/jobs/avatar_retention_purge_test.rb`
  Result: `96 runs, 219 assertions, 0 failures, 0 errors, 0 skips`.
- Rails full gate with the same isolated manifest and `bundle exec rails test`:
  `15012 runs, 127297 assertions, 0 failures, 0 errors, 0 skips`.
- `bundle exec rubocop --parallel`: 5342 files inspected, no offenses.
- `git diff --check`: passed.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: zero warnings and zero errors.
- `bundle exec rails zeitwerk:check`: passed (`all is good`; the existing `rails_db` eager-load
  advisory remains informational).

## Limits

The new validation is an application save boundary. It does not prove that
`update_columns`, `update_all`, `upsert`, or direct SQL cannot mutate a public ID. The required
database-level immutability mapping and any narrowly authorized database enforcement remain an
open P2/P6 implementation item; this slice does not claim global identifier acceptance.

The full nine.md implementation remains incomplete in the separately recorded P3d physical OTP
column retirement, P6 database-wide identifier inventory/enforcement, P9 public transfer cutover,
P10b Group semantics, and P12 transition/cutover work.
