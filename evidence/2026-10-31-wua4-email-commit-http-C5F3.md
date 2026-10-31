# WU-A4 Email preference OP commit and HTTP dependency response

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked worktree
changes affected the run. Tests used local test databases; production and Neon were not targeted.

Added a nontransactional local test that injects a failure during the Zenith Email update. An
independent OP connection observed the Step-Up evidence already consumed before that failure;
the Email preference remained unchanged, and the operation returned its dependency failure. The
test removed only the actor, Email, token and device rows that it created. The focused case passed:
1 run, 5 assertions.

Extended the authenticated Base app Email preference HTTP journey with an injected operation
dependency failure. The endpoint returned 503, preserved the Email value and left Step-Up evidence
available; the same journey then performed its normal successful update. The focused case passed:
1 run, 9 assertions. This tests the controller response mapping, while the nontransactional case
tests the separate-connection commit observation; it is not an end-to-end injected DB outage.

The selected concurrency, operation and HTTP tests passed together: 7 runs, 44 assertions, no
failures, errors or skips. RuboCop reported no offenses in the two touched tests after a
formatting-only correction; scoped `git diff --check` passed. Target-bound Step-Up, atomic audit,
other concurrency orders and complete XDB-03 acceptance remain open.
