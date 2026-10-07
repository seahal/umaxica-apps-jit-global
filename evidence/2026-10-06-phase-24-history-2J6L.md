# Phase 24 browser-history evidence

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`
- Date: 2026-10-06 UTC
- Worktree: dirty with the browser-history implementation, generated dumps, documentation/harness
  changes and unrelated concurrent edits preserved.

The focused Vitest run passed: `3 files passed, 30 tests passed`, including the SurfaceLayout
`router.clearHistory()` behavior and the Secret/page-history presentation checks.

After migrating the remaining retired Auth settings-page imports to the delivered Base identity
pages, the complete JavaScript command passed: `bun run test` reported `100` files and `1149` tests,
with no failures or errors. The one-time CSRF cancellation component also passed its focused `4`
tests after the submit-time token was made state-backed.

A current rerun also passed `bun run test` with `100` files and `1149` tests, and `bun run typecheck`
completed successfully.

The focused Rails controller run for sign-in limitation history markers passed with `7 runs, 38
assertions, 0 failures, 0 errors, 0 skips`. The existing cache/Inertia contract command separately
reported `22 runs, 33 assertions, 17 failures`, all redirect/401 failures from the existing
authentication test helper's token preparation mismatch; no current Phase 24 file was changed to
hide those failures.

The implementation uses official Inertia history primitives only. `encrypt_history` remains enabled
for ordinary navigation, and terminal markers are carried through redirect chains so stale mutation
is still rejected by server-side lifecycle checks.
