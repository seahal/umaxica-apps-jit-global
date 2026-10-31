# WU-A4 TOTP Step-Up device precheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting implementation and tests.
- The Step-Up TOTP verification file initially passed (2 runs, 14 assertions). New revoked-device and superseded-token cases both failed before the change because verification did not raise (4 runs, 16 assertions, 2 failures).
- The operation now locks the device and token during its Ticket binding check and rejects a revoked, foreign, rebound or superseded device before TOTP source verification. Both new cases retain the unconsumed TOTP and pending ceremony.
- The TOTP Step-Up and enrollment finalizer files passed after the change (10 runs, 89 assertions, 0 failures, 0 errors, 0 skips). RuboCop passed for the operation and test; the client Step-Up diagram and inventory record the check and its limit.
- This check releases device and Ticket locks before Zenith verification and subsequent Ticket evidence recording. Therefore it does not prove safety against a revocation between those steps. Preserving independently committed source proof and avoiding lock inversion requires further cross-database design and race tests. Passkey Step-Up device validation and the enrollment finalization order/audit gaps were not fixed here.
