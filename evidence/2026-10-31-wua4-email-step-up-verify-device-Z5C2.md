# WU-A4 Email Step-Up verification device binding

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting implementation and tests.
- The existing verifier file passed before the change (2 runs, 18 assertions). Four new combinations of revoked/superseded device and valid/invalid code failed before the fix (6 runs, 24 assertions, 4 failures): a valid code advanced proof and an invalid code altered the source failure count.
- The verifier now holds the owner, Email, device, token, session and parent locks in order, verifies device ownership and current-token binding, and refuses before code consumption or failure updates when the device is unavailable. The cases retain the pending parent, unconsumed code, failure count and token freshness.
- The issuer, delivery recorder, verifier and Auth Email controller files passed (18 runs, 132 assertions, 0 failures, 0 errors, 0 skips). RuboCop passed on the operation and test. The Email challenge diagram and transition inventory were updated.
- This does not establish independent-connection races or the behavior of already queued delivery after device revocation. Cross-database failure windows, including outer transactions and source failure counter versus Ticket evidence, remain open.
