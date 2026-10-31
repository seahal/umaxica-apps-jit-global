# ORG logout test registry isolation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting the checks.
- The JWKS separation check from full-suite seed 54824 passed alone (1 run, 20 assertions).
- Reconstructed the class order using the Rails/Minitest loader and that seed: the ORG Visa logout test class preceded the separation class, with one intervening class. Its setup configures one generated key for several issuer namespaces and reloads the registry; the common environment teardown did not reload it.
- Running the ORG logout route test followed by the separation test with seed 54824 reproduced the JWKS failure (2 runs, 18 assertions, 1 failure). Added teardown to restore the saved environment and reload the registry, matching the earlier APP logout correction.
- The same two-test sequence passed (2 runs, 28 assertions). The full ORG logout test file plus the separation check passed (16 runs, 114 assertions, 0 failures, 0 errors, 0 skips).
- This reproduces and corrects a local test-state leak; it does not verify deployed keys or exclude other test-state leaks. The full suite was not rerun after this correction.
