# Standby Secret bootstrap

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A service test for a Standby token and an operator with no Passkeys failed before the change: the focused file had 10 runs, 36 assertions and 1 failure because Secret bootstrap succeeded.
- The bootstrap controller guard now checks the session's Step-Up capability before allowing the no-method exception. The ORG Secret creation operation also refuses a Standby token under its session lock, including bootstrap.
- The Secret creation, Step-Up response and guard files passed together: 21 runs, 62 assertions, no failures or errors. RuboCop passed for the changed concern, service and test.
- An attempted HTTP test with a new operator without Passkeys was refused earlier with `SECOND_PASSKEY_REQUIRED`, before reaching the bootstrap guard; that temporary test change was removed. The existing HTTP response test passes for a Standby session with its fixture credentials, but does not prove HTTP reachability of the no-Passkey bootstrap branch. A live Standby-to-Root journey and all WU-A6 operations remain unverified.
