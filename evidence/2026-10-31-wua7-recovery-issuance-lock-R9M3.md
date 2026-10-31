# APP security-lock recovery issuance recheck

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- An HTTP test ran real OTP verification and then released the Email binding before the controller issued the recovery ceremony. Before the change it failed because a ceremony was created (1 run, 3 assertions, 1 failure).
- APP recovery completion now locks the Client, Email and matching in-force security-lock Cases in deterministic Case ID order, verifies the OTP, then rechecks the Email and eligible Case before creating the recovery ceremony. No normal authentication cookie is issued on refusal. Current architecture documentation was updated.
- The Email-release and real Case-end injected cases passed together (2 runs, 12 assertions); the latter was added after the change. The recovery HTTP/action, reentry issuer/verifier and withdrawal files passed together (30 runs, 312 assertions). RuboCop passed for the changed concern and test.
- These tests use transactional fixtures and synchronous mutation immediately after real OTP verification; independent-connection lock ordering, failure at each database commit, ORG recovery and the explicit withdrawal-state migration remain unverified. A refused post-verification attempt may have spent its one-time OTP, as documented.
