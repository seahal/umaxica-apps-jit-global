# Sign-in resend cooldown fractional precision

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the inspected implementation.
- The existing policy and resend service tests passed: 35 runs, 159 assertions, no failures, errors or skips.
- A temporary service-level test injected an occurrence DB issuance clock at a `.900000` fractional second and a subsequent clock 29.2 seconds later. Both requests returned success: 1 run, 2 assertions. The test used a dummy address and did not contact a delivery provider.
- The occurrence writer converts issuance times to integer seconds; parsing therefore loses the fractional part before the existing policy evaluates the cooldown. This test demonstrates early eligibility for the chosen boundary, not the frequency of the condition in production.
- The probe was not added to the repository as a regression test because it asserts the current defective behavior. No persisted-format change, data migration, production inventory, real delivery or full suite was performed.
