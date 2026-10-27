# Cycle stage 3 resumed checks

- HEAD `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; the worktree was dirty and included uncommitted cycle and sign-out changes. Results are local and do not establish deployment acceptance.
- `PARALLEL_WORKERS=1 bin/rails test` on the selected WU-30 Security Mode and Step-Up resolver tests: 30 runs, 41 assertions, no failures/errors/skips. The owner-held WU-30 follow-ups were not started.
- The selected WU-38 cleanup, hold, job and concurrency tests: 71 runs, 489 assertions, 2 failures, no errors/skips. `SignUpPasskeyTerminationHttpTest` at line 349 expected 409 but received 201 at and after the Flow deadline. The implementation was not changed in this verification step.
- The selected WU-43 callback, target, state, redirect and security invariant tests: 62 runs, 463 assertions, no failures/errors/skips.
- The preceding 1a and 1b results and the exact test-file inventory are in `evidence/2026-10-26-cycle-stage3-execution-V4F2.md`. WU-26 has since been withdrawn by D-196; its removal is a later cycle task. A passing file set does not by itself prove unasserted acceptance cases. Partial assertions, full-suite triage and documentation reconciliation remain separate tasks.
