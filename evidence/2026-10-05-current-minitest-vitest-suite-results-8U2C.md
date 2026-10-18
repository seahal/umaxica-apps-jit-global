# Current Minitest and Vitest suite results

Executed on 2026-10-05, starting at approximately 16:24 UTC, against HEAD
`e8f2371bc5cbefd2087c728aeeef4e318463d33f` with existing uncommitted changes.
The user requested verification only and explicitly stopped implementation.
No implementation or test files were edited during this verification.

| Runner | Outcome | Reported counts | Duration |
| --- | --- | --- | --- |
| Vitest | Completed, exit 0 | 100 files passed; 1148 tests passed; zero failures | 13.31 seconds |
| Minitest | Interrupted, exit 1; incomplete suite | 7366 runs; 49990 assertions; 134 failures; 90 errors; 1 skip | 641.599985 seconds |

Commands:

- `bun run test`
- `bundle exec ruby /tmp/umaxica-secret-recovery-db-task.rb test`

The Minitest wrapper runs `bin/rails test` with one worker and verifies the
task-owned PostgreSQL 17.7 fleet identified by
`tmp/app-secret-20261005recovery-manifest.json`. It did not apply destructive
changes to shared databases. The random seed was 3058.

Minitest output stopped progressing at 16:29:58 UTC. The current Ruby process
remained alive in `futex_do_wait`; a read-only activity inspection found no
reported database blockers among observed task-fleet connections. After roughly
five minutes without new output, only this verification's Ruby process
(PID 591689) received SIGINT. Minitest printed `Interrupted. Exiting...` and
reported the counts above. These are reached-test counts, not a completed
full-suite result. The test responsible for the stall was not identified.

The 224 emitted failure/error reports match 134 failures plus 90 errors.
Examples include the old all-surface Secret-route absence invariant, com/org
credential removal constraints, TOTP registration and OIDC transaction tests.
Their names do not establish that all failures are caused by app Secret changes.
No baseline comparison, fixes, exclusions, E2E, or second suite run was performed.
Raw output remains outside `evidence/`; this record retains only observed results.
