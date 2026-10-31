# RP sign-out confirmation referrer policy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes affecting the checked implementation and tests.
- Changed the shared sign-out notice header to `strict-origin` on the `edit` confirmation action. Other actions retain `no-referrer`. The existing same-origin POST forms and CSRF checks were not altered.
- The focused Base APP and Core APP edit cases passed: 2 runs, 29 assertions. Base APP/ORG, Core APP and Warp ORG sign-out controller files and both CSRF invariant files passed together with `PARALLEL_WORKERS=1`: 33 runs, 243 assertions. These include `strict-origin` checks for APP/ORG confirmations and a `no-referrer` check on a Warp ORG non-edit response.
- `git diff --check` passed. RuboCop reported two method-length offenses in pre-existing methods of the Base APP/ORG test files; it reported no offenses in the concern, Core or Warp files.
- No real browser was used for these particular forms. OIDC end-session confirmation can render from a `show` action, which still uses `no-referrer`; its separate flow was not changed or verified by this check.
