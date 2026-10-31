# Step-Up retry and root-device stop ordering

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had substantial uncommitted changes affecting the checks.
- An independent-connection APP HTTP test held the Client row lock, then retried a redeemed Step-Up admission. Before the fix, the retry returned 303 without waiting for the held Client lock (1 run, 1 assertion, 1 error from the test's wait check). This is an observed missing serialization; it does not establish behavior of a deployed replica.
- The coordinator previously looked up the binding's Base token before entering its writer role, and treated an absent result as an anonymous binding. It now reads the token from the owning writer and explicitly refuses when a binding names a token that cannot be loaded, before deciding whether to acquire the actor lock.
- APP and ORG tests observed the retry connection blocked by the specific Client/Operator lock holder, revoked that root device, then observed 400 without a new Auth SID or admitted session. The parent remained pending. The two cases passed (2 runs, 14 assertions).
- The broader admission, issuer, verification and concurrency group passed (142 runs, 1,767 assertions). After formatting, all four cancellation/root-stop races passed again (4 runs, 26 assertions). The first scoped RuboCop run reported one layout offense, which was corrected.
- Reverse order, actual deployed replication and a full-suite comparison after this change remain unverified.
