# TOTP rename with an outer Ticket transaction

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the TOTP rename implementation and its existing commit-order test; the results describe that worktree.

- `PARALLEL_WORKERS=1 bin/rails test test/concurrency/identity_totp_name_commit_order_test.rb` passed: 1 run, 4 assertions. This checks the standalone operation with an injected Zenith write failure.
- A temporary nontransactional probe ran `IdentityTotpNameCommitter.call!` inside an outer `OpBaseAppRecord.transaction`, then rolled the outer transaction back. It passed 2 assertions: Zenith retained the renamed title and Ticket restored the previously consumed Step-Up timestamp. The probe used records it created and was removed after execution.

The standalone test does not establish a commit boundary when the caller already owns a Ticket transaction. Current direct application calls were found in the APP TOTP controller; their runtime transaction state was not established. No fix or HTTP exploit was verified by this probe.
