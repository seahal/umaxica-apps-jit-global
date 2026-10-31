# WU-A4 Email Step-Up issuance device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The issuer test file initially passed (3 runs, 16 assertions). New revoked-device and superseded-token cases both failed before the change because code issuance did not refuse (5 runs, 18 assertions, 2 failures).
- The issuer now locks the owner, Email credential, device and token in that order, and checks device usability, ownership, current token and session binding before issuing a code generation or enqueueing delivery. The new cases verify refusal, unchanged generation and source issuance timestamp, and no delivery job.
- The issuer, delivery-recorder and verification files passed together after the change (11 runs, 68 assertions, 0 failures, 0 errors, 0 skips). RuboCop passed after a formatting correction; the Email Step-Up challenge diagram and transition inventory were updated.
- This does not establish independent-connection race orderings. Delivery after a previously issued generation and the separate Email verification operation have not yet been protected by this change; SMTP is outside the issuance locks.
