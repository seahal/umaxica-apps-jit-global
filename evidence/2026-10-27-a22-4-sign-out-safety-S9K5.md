# A22-4 / G-16: sign-out safety, request and concurrency level

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes, including today's Auth `/ceremony_bindings` framed-request refusal (R7T3) and the
  point-in-time revoke-others fix (N3C9).
- G-16 is covered by A14-*, A15-3, A44-6 and A44-10 (`three.md` gate table). All 27 rows are Passed
  (A14-1 … A14-18 incl. 5a–c, 9a–c, 10a–c; A15-3; A44-6; A44-10).
- Re-run after today's changes: `PARALLEL_WORKERS=1 bin/rails test` on 21 files — the current-device,
  enqueue-failure, registered-RP matrix and realm-acceptance integration tests, the rotation
  concurrency test, the back-channel receiver, `op_outbox_dispatch_job_test.rb`, the revoke-others
  operation test, the single-writer invariant, the logout-current-session concern test, the Base OIDC
  logout controller tests and every `*/sign/outs_controller_test.rb` — 261 runs, 2,481 assertions,
  0 failures, 0 errors.
- Not covered here: the browser part of A22-4 (the owner's manual check, `ten.md` §5), deferred to the
  next cycle (`nine.md` BL-14). Back-channel delivery to a real endpoint cannot be observed in
  development (`docs/backlog/2026-10-27-backchannel-logout-unverifiable-in-development.md`).
