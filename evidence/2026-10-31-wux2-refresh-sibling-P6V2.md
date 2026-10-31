# Historical refresh cases: separate grant scope

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the token exchange implementation and tests; the results apply to that worktree.

The existing APP replay and unknown-token tests now also create a separate Warp grant on the same Root and check that its refresh credential can still rotate after the tested Core grant's replay or invalid credential. `PARALLEL_WORKERS=1 bin/rails test test/services/oidc/token_exchange_service_test.rb -n '/D-25.*(reuse|unknown)/'` passed: 2 runs, 17 assertions.

An initial version tried two active grants for the same device/client and hit the existing unique constraint; it was corrected to use a different registered client. A second intermediate assertion incorrectly treated the lookup result as a success result; it was corrected to call the refresh issuer. Both intermediate runs failed; the final result above is the retained test.

This covers APP and one distinct sibling client and the immediately preceding refresh token. It does not establish older predecessor handling, every sibling realm/client, or ORG.
