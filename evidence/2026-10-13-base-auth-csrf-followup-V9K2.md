# Base/Auth strict CSRF follow-up

Verified on 2026-10-13 against full HEAD `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch
`feature`. The worktree was extensively dirty before this follow-up; the results include the current
uncommitted implementation and test changes. `one.md` and `two.md` remain unchanged.

The user selected one.md's strict Base/Auth contract: every unsafe request requires a valid Rails
authenticity token, including same-origin requests. The Rails hybrid strategy and prior same-origin
acceptance do not create an exemption. Browser-flow coverage refreshes the token from the ordinary
Base page after Root establishment rotates the session, then retries the same completion request.
No CSRF bypass or same-origin exception was added.

The Jump registry now has complete test key material for its thirteen required issuer namespaces,
and its malformed-JWKS assertion matches the current public configuration error. The Jump token
codec declares its public class-method section explicitly; its resolved visibility-baseline entry was
removed. The edited test host lookup uses one-argument `ENV.fetch`.

Verification used only the standard Rails `test` database configuration, with
`POSTGRESQL_ISOLATED_TEST_RUN_ID` unset. The combined relevant selection passed: 186 runs, 10,017
assertions, 0 failures, 0 errors and 0 skips. The CSRF static guards passed: 6 runs, 12 assertions,
0 failures, 0 errors and 0 skips. RuboCop reported no offenses in the 15 targeted Ruby files, and
`git diff --check` passed. No migration, reset, backfill or cutover was run.

An earlier full-suite run, before this follow-up's token, registry-fixture and baseline fixes, ended
with 15,255 runs, 127,832 assertions, 14 failures, 53 errors and 0 skips. It reported the social
duplicate-completion retry, Jump registry fixtures, the now-resolved codec baseline entry, and
additional sign-out, RP-session, passkey, presentation and worker-receipt cases. The full suite was
not rerun after this follow-up; its current status is therefore unverified. Step 9's production-like
boot still lacks the required `TRUSTED_PROXIES` input, and the overall plan remains open under its
previously recorded Step 5, Step 6 and deferred Step 8 gates.
