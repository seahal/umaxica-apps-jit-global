# Step-Up admission same-browser retry

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had substantial uncommitted changes affecting the implementation and tests.
- The existing APP verification retry test reproduced the prior 400 instead of its expected 303 (1 run, 2 assertions, 1 failure).
- A redeemed Step-Up binding now reaches the existing same-browser retry path. Under the existing actor, device, token, parent, binding and ceremony-session locks, the retry rechecks the parent, root, purpose and binding expiry before the clean redirect. It does not create a new session or issue an Auth SID.
- APP and ORG HTTP tests exercise another browser, retries at 9, 10 and 11 seconds after binding issuance, and a revoked root device. The APP test also cancels the parent and checks refusal. The verification and admission/coordinator group passed: 120 runs, 1,466 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop initially found two ternary-format offenses in new assertions; both were corrected. Real-browser behavior, independent-connection retry-versus-cancel/stop races, the ORG canceled-parent case, and a full-suite run after the change remain unverified.
- Scoped RuboCop passed after the formatting correction (5 files, no offenses).
