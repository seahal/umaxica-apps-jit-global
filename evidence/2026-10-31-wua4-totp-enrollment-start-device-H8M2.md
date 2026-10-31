# WU-A4 TOTP enrollment start device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- Baseline: `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_totp_enrollment_issuer_test.rb` passed (5 runs, 35 assertions). A new revoked-device case failed before the fix because no error was raised (1 run, 1 assertion, 1 failure).
- TOTP enrollment start now takes the owner, device and token locks in that order and requires the locked device to be usable, owned by the actor, still bound to the token, and pointing to that token as current. This check precedes creation or return of a candidate.
- The issuer, verification and finalizer files passed together (18 runs, 227 assertions). The added operation case covers revoked and superseded devices, both before initial candidate issuance and when resuming an existing candidate. One intermediate test setup hit the per-user session limit; it was corrected to use a separate actor for each partition. RuboCop found no offenses in the two changed files.
- The verification operation's own device-revocation boundary, independent-connection races, actual browser requests and the TOTP finalizer's separate cross-database ordering defect were not resolved or verified by this change.
