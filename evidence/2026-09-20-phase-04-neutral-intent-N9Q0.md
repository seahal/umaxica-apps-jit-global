# Phase 04 neutral browser RP intent verification

Date: 2026-09-20

## Scope

This slice makes ordinary authorization requests from the seven first-party browser RP client
IDs use the neutral `authentication` intent. Native/Palm and deprecated shared browser clients
retain their existing `screen_hint` purpose behavior. The change also supplies the issuer-derived
HTTPS protocol when Base com/org builds Auth handoff URLs; without it, a local HTTP test request
could produce an unsafe external HTTP target and be rejected by the existing Jump RT boundary.

## RED and correction

- The new three-surface integration assertion first reached the expected app controller, then
  exposed that the test helper's stale `Host` header could route the com/org request as app.
- After making the test request host explicit, the app case passed but com returned 422 because
  the com Auth handoff URL inherited the test request's HTTP scheme.
- The production correction was limited to passing the existing issuer-derived HTTPS protocol in
  the com/org Auth sign-in/sign-up URL helpers. No Jump RT cryptographic, key, replay, audience, or
  trust model was changed.

## Verification

- Focused neutral-intent test: 1 run, 15 assertions, 0 failures, 0 errors, 0 skips.
- Base OIDC authority file: 42 runs, 224 assertions, 0 failures, 0 errors, 0 skips.
- Combined OIDC/transaction/admission/Valkey/RP registry set: 167 runs, 942 assertions,
  0 failures, 0 errors, 2 skips. One earlier run had a transient Valkey unavailable error while
  preparing an unrelated wrong-grant-type case; rerunning that case passed before the successful
  combined run.
- Full Rails suite: 11,363 runs, 72,545 assertions, 0 failures, 0 errors, 5 skips.
- RuboCop on the changed OIDC, transaction, Valkey, and test files: no offenses detected.
- `git diff --check`: run after the slice; no whitespace errors.

No database reset, external service write, GitHub write, commit, or push was performed.
