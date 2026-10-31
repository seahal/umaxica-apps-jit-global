# WU-A4 XDB-04 TOTP rename ordering slice

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected this run. Tests used local test databases; production and Neon were not targeted.

The original operation updated the Zenith title before OP Step-Up consumption. A failure injection
observed the new title during the consumption call and the added case failed before the change.
The operation now locks the Zenith actor and owned credential, validates the proposed title,
commits the OP authorization consumption, then saves the title. An unchanged title retains the
existing no-op behavior. Storage dependency failures are represented separately and the Base
controller maps them to 503.

A nontransactional test injected a failure during the Zenith update; an independent OP connection
observed consumed Step-Up evidence before the failure and the original title remained. The test
removed only its own generated credential, token, device and actor rows. The focused case passed:
1 run, 4 assertions. The operation, independent-connection and credential-removal regression tests
passed together: 13 runs, 48 assertions, no failures, errors or skips. RuboCop reported no offenses
in the four changed Ruby files.

This is not XDB-04 completion: per-credential Step-Up binding, a same-Zenith-transaction audit,
the public HTTP dependency-failure response and remaining race directions are not established.
