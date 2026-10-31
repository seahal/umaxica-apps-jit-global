# ORG Passkey sustained rate limits

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes affecting the application and tests.

The existing ORG Passkey options and verification sustained-limit tests used the removed Admission form. Before the edit, their focused run had 2 errors and no assertions. They now use the current Admission redirects with direct binding confirmation. Without a pending Entra transaction, each test checks 20 refused requests over four one-minute-spaced bursts, then a 429 with `Retry-After: 900` on the next request.

With the configured local test environment, the sustained pair passed (2 runs, 52 assertions) and all four ORG Passkey options/verification burst and sustained cases passed together (4 runs, 72 assertions). RuboCop and `git diff --check` passed for the modified file. Time travel and the in-memory limiter were used; an actual distributed 15-minute run, a successful Entra-to-Passkey journey, the complete Base browser confirmation and other limiter cases remain unverified. No production code changed. Temporary raw test logs were removed.
