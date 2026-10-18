# Phase 19 contact binding evidence

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`
- Date: 2026-10-06 UTC
- Worktree: dirty as described in the other current evidence records; no unrelated change was
  reverted.

The Phase 19 binding/OTP operation set failed with `232 runs, 777 assertions, 0 failures, 1 error,
0 skips` when the old Auth email controller tests were excluded. The single error was the
COM registration test's `exceeds maximum concurrent sessions per visitor (2)` setup failure.

The broader first run also exposed 43 failures and one error in old Auth email tests that still
assert the pre-D82 `303` contract, plus the same COM session-cap setup error. Those are stale
expectations or setup failures, but have not been reproduced against the Phase 0 baseline.
They remain UNCLASSIFIED, not pre-existing, until diagnosed or reproduced. This record does
not establish Phase 19 acceptance.

## Takeover verification, 2026-10-07

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`; the inherited and current changes remained
uncommitted. Only the owned `20261007fresh3` disposable fleet was used, one worker.

Contact binding constraints, Source audit, email/telephone final committers and audit delivery job:
49 runs/514 assertions, no failures/errors/skips. Approved signup Source proof, fixed retry
deadlines and delayed transport results are recorded in
`evidence/2026-10-07-auth-email-delivery-binding-R7K2.md`; its counts are targeted checks, not
whole-Phase acceptance. Authenticated destination-confirmation lifecycle remains under review.
