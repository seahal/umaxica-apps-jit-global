# Visa binding confirmation headers across realms

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including the shared confirmation concern and test; these observations apply to that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb:777` passed before the new assertions (1 run, 111 assertions) and afterward (1 run, 117 assertions). The test exercises APP sign-in and sign-up and ORG sign-in. For each, the original browser receives a read-only Visa confirmation form with `strict-origin`; a foreign browser receives a refusal with `no-referrer` and does not confirm the binding. The same test also exercises the existing automatic continuation.

This covers Visa's shared confirmation concern, not a Base ORG confirmation form or an actual browser. Those remain unverified.
