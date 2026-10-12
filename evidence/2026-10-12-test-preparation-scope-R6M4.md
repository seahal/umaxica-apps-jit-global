# Test preparation scope repair

- Repository: `/home/global/workspace`
- Branch: `feature`
- Code HEAD used for this record: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`
- The worktree had 224 changed paths when this record was written; no reset, clean, stash,
  worktree, push, production operation, or shared-database operation was used.

## Change

`config/ci.rb` now passes the six non-replica test databases owned by the current Rails test
configuration to the guarded `db:test:prepare` task:

`test_primary_db`, `test_app_ticket_db`, `test_com_ticket_db`, `test_org_ticket_db`,
`test_app_zenith_db`, and `test_chronicle_db`.

The local run-owned manifest used for verification already contained the corresponding isolated
databases. The guarded preparation task completed successfully; the subsequent focused and full
Rails suites passed. No CI job was invoked.

After the existing static configuration test was updated to accept the split source representation,
the focused configuration contract passed with `15 runs, 60 assertions, 0 failures, 0 errors,
0 skips`. The post-change full Gate 2 was then run against the same 20-database manifest: Rails
passed with `15155 runs, 128346 assertions, 0 failures, 0 errors, 0 skips` in 330.574606 seconds,
and `bun run test` passed `99` files and `1140` tests in 12.94 seconds.

The first bounded gate process left the worker-3 receipt without its completion field because the
outer wait ended before the parent cleanup callback wrote it. Read-only catalog inspection found
exactly the twenty worker-3 databases named by that receipt, all owned by `root`; the existing
receipt-verified cleanup helper then removed only those databases and set `cleanup_completed: true`.
A second read-only catalog query found zero worker databases for workers 0 through 3.

## Verification

- `ruby -c config/ci.rb` — passed (`Syntax OK`).
- `git diff --check` — passed.
- The repository's existing `.github/workflows/ci.yml` remains mounted read-only in this
  development container and still contains the older four-name literal. It was not bypassed or
  edited. A host-side workflow update to the same six-name set is required before the GitHub job
  can be considered aligned; this record does not claim CI verification.

