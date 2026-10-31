# Historical A30-6: ORG one-Passkey sign-in journey

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the sign-in implementation and test; the result applies to that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/integration/org_root_login_establishment_test.rb:14` returned 1 run, 50 assertions, 1 failure. The test constructs an Operator with one Passkey, uses a local fake provider transport and WebAuthn, and reaches a Base callback with RP access and refresh cookies. It then observes the registration redirect. The later assertion expects a birthdate Step-Up scope, but the actual redirect is to `/identity/passkeys/new`; this failure ID is listed in `plans/2026-10-28-baseline-failing-tests.md`.

The test did not complete, and it does not negate the separately reproduced Passkey inventory gate gap in `evidence/2026-10-31-wux2-org-one-passkey-gate-V6J8.md`. No production change was made. The entire A30-6 acceptance case remains failed/incomplete.
