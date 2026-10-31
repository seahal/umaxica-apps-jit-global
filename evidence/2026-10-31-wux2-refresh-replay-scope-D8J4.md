# Historical refresh cases A10-2 and A10-3

HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had extensive uncommitted changes, including token exchange code and its tests; the result applies to that worktree.

`PARALLEL_WORKERS=1 bin/rails test test/services/oidc/token_exchange_service_test.rb -n '/D-25.*(reuse|unknown)/'` passed: 2 runs, 11 assertions. The consumed-token case verifies `invalid_grant`, revocation of the observed grant and successor, and an active Root. The unknown-token case verifies a forged verifier and malformed token return `invalid_grant`, leave the observed grant unrevoked, and leave its valid token usable.

These tests do not assert a second independent grant remains active after replay, or all grants remain untouched after an unknown token. The historical requirements include those wider scope claims, so both dispositions remain partial. They do not establish current credential-version requirements.
