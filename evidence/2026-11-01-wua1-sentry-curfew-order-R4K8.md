# WU-A1 Sentry precedes Auth curfew handling

Date: 2026-11-01

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`

The worktree had existing uncommitted changes. This change also remains uncommitted; no commit was
created.

## Change

APP and ORG Auth application controllers now run Sign Entry Sentry before admission-curfew handling.
A new acceptance case covers an attached, Base-confirmed and redeemed admission with Sign In
unavailable at one second before, exactly at, and one second after the stored curfew. It compares
the binding, admitted ceremony, OIDC transaction, sign-in/sign-up flows, and browser cookies before
and after each request. The authentication checklist records this contract.

## Verification

- Before reordering the callbacks, the new acceptance case failed for APP one second before curfew:
  expected 503, received 303. The test command reported 3 runs, 71 assertions, 1 failure.
- After reordering,
  `PARALLEL_WORKERS=1 bin/rails test test/integration/acceptance_wu29_sign_entry_sentry_blocked_test.rb test/integration/admission_curfew_test.rb`
  passed: 11 runs, 152 assertions, 0 failures, 0 errors, 0 skips.
- Ruby syntax checks passed for both Auth application controllers and the acceptance test.
- Scoped RuboCop passed for those three files with no offenses.
- `git diff --check` passed.

## Not verified

The full suite was not run. This check does not close the WU-A1 runtime matrix or verify behavior in
a real browser.
