# WU-A4 credential removal owner availability

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained uncommitted changes affecting the implementation and tests.
- Baseline: `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_credential_removal_committer_test.rb` passed (14 runs, 168 assertions).
- A new focused test created valid TOTP removal Step-Up and then changed its Client to `RESERVED`. Before the fix, removal returned success instead of refusal (1 run, 1 assertion, 1 failure). An earlier setup attempt errored on a stale Client and was corrected by reloading the actor.
- The removal operation now checks `login_allowed?` while holding the actor lock and refuses before the Ticket and credential mutation when the owner is unavailable. Tests cover a blocked Client with TOTP and blocked Client and Operator owners with Passkeys, retaining the credential and previous Step-Up.
- After the change, the removal, Passkey authorization and concurrency files passed together: 28 runs, 286 assertions, 0 failures, 0 errors, 0 skips. RuboCop found no offenses in the three changed Ruby files.
- This does not fix or verify the separate outer Ticket transaction defect, establish independent-connection owner-stop races, or complete XDB-07. Contact removal and other unavailable states were not separately exercised in this slice.
