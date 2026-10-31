# Step-Up retry cancellation and root writer

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained substantial uncommitted changes affecting the checks.
- A nontransactional APP HTTP retry test created a Client and root, admitted a Step-Up, and initially raised `NoMethodError` while resolving the root actor. The coordinator now resolves the token's Client or Operator on that actor's writer and raises its existing `Denied` type if the actor cannot be found. The initial error alone does not prove a deployed replica-lag event.
- Separate APP and ORG tests hold the actual parent row lock, start an HTTP retry on another PostgreSQL connection, observe that it is blocked specifically by the parent holder, commit cancellation, and observe 400 with no Auth SID issuance, no second admitted session and the original binding retained. Both cases passed: 2 runs, 12 assertions.
- The related admission, coordinator, reference race and verification group passed: 124 runs, 1,486 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop passed after formatting; the two focused race tests passed again after formatting.
- The reverse ordering, retry versus root stop, actual production replication, real browsers and a new full-suite comparison remain unverified.
