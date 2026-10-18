# Authority index contract check

Date: 2026-09-18 (UTC)

Target: local `feature` worktree at `6f9e1c3c6206cda5fbc2baab038495d65e92042e`, with the
pre-existing unrelated working-tree changes preserved.

## Change

The three not-yet-enabled authority schema migrations now pass `index: false` to every
`t.references` declaration. Each required lookup index remains explicit: ownership uniqueness and
reverse-principal indexes, grant composite uniqueness and reverse-principal indexes, and transfer
request pending/destination/due indexes. This avoids redundant automatic single-column indexes
beside the explicit indexes.

The authority schema contract test now checks that every authority reference opts out of the Rails
automatic index. No table, foreign key, column, or authority behavior was removed.

## Verification

- `bundle exec ruby -e '...authority migrations...'` — passed; all three migrations reported
  `references=25 missing_index_false=0`.
- `bundle exec ruby -c` for all three migrations and the contract test — passed.
- targeted RuboCop for the changed contract test — passed.
- `git diff --check` — passed.
- `scripts/test-isolated bin/rails test test/models/authority_schema_contract_test.rb` — not
  executed to assertions. The isolated test preflight could not connect to PostgreSQL at
  `127.0.0.1:5432` or Valkey at `127.0.0.1:6379`; no non-test datastore fallback was used.

The schema migrations were not applied to any database in this session. Runtime index inspection,
migration rollback, and concurrent authority tests remain blocked by the isolated-service conflict
recorded in `conflict.md` (CF-002).
