# Base Step-Up restart and conflict referrer policies

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting this result.
- Targeted APP restart and conflict tests initially saw `no-referrer` instead of `strict-origin` (2 runs, 20 assertions, 2 failures). Both rendered forms now send `strict-origin` in their response header and HTML metadata.
- The APP restart, conflict choices with CSRF/cross-site refusal, and expired-binding restart tests passed: 3 runs, 40 assertions, 0 failures, 0 errors, 0 skips. Scoped `git diff --check` passed.
- RuboCop on `base_step_up_intent.rb` reported two complexity offenses in `redirect_to_step_up_ceremony!` and the method at line 120; those methods were not changed in this slice. ORG render and deployed browser flows were not separately tested.
