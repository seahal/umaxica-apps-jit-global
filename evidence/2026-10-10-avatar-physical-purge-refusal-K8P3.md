# Avatar physical purge refusal

Observed on 2026-10-10 against HEAD `2a1644f73238839ed7ed513bd4681ea393a86682`
with uncommitted application, test, migration and documentation changes. Scope: nine.md P11b,
Avatar D-6, and AV-9 in `docs/checklists/avatar-ownership.md`.

The new public job regression initially failed: an eligible Avatar without concrete ownership
periods was physically deleted. Red: one run, one assertion, one failure, zero errors/skips.
The job now records `retention_policy_pending` instead of deleting that Avatar. Avatars with
concrete history keep their `ownership_history` deferral. Repeated runs retain Avatar, handle,
and encrypted moniker history and update one reason-scoped observation. This does not decide a
personal-data retention duration or authorize indefinite retention.

Focused command: `bundle exec rails test test/jobs/avatar_retention_purge_test.rb
 test/jobs/retention_purge_job_test.rb` (single command, both explicit files).
Result: 21 runs, 90 assertions, zero failures/errors/skips. The old moniker-cascade test was
updated to the approved no-physical-deletion contract and now checks both monikers remain.
`bundle exec rubocop app/jobs/retention_purge_job.rb test/jobs/avatar_retention_purge_test.rb
 test/jobs/retention_purge_job_test.rb`: three files, no offenses. `git diff --check` passed.

Rails used the owned isolated fleet manifest `tmp/acceptance-isolated-20261010p8b-primary.json`,
run `20261010p8b`, host `primary`, test/Rack environment, workers 1, and the manifest's complete
prepare database list. No shared/production database or external service operation was performed.

Gate 2 started after focused Green: `bundle exec rails test` under that same environment and
`bun run test`. Vitest completed successfully: 99 files and 1,140 tests passed, exit 0, duration 13.05 seconds.
Rails completed with exit 0: 15,013 runs, 127,308 assertions, zero failures/errors/skips,
949.455052 seconds. Both full Gate 2 runs therefore completed successfully for this slice.
The existing Flipper duplicate-memoizer warning was emitted; no test failed.
After the full run, `git diff --check` passed. During the gate the owning Avatar specification
was reconciled with approved D-1–D-11; only documentation changed while the suite ran. No commit or push was performed during this slice.
