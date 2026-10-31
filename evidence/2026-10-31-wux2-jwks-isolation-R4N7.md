# Visa/Base JWKS full-suite discrepancy

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting this result.
- The full suite reported that the APP Visa and Base JWKS had overlapping public key material in `AcceptanceWu02JwksSeparationTest`. This test name was not in the baseline or prior full-suite failure list.
- Ran the test alone: one run, 20 assertions, no failures or errors. Also ran the JWT registry tests, well-known JWKS controller tests and this integration test together with the full-suite seed 40202: 33 runs, 257 assertions, no failures or errors.
- The inspected JWT registry tests temporarily configure the same generated surface key for multiple namespaces and restore registry state in teardown; this is a possible source of shared-process contamination, not an established cause. The focused runs do not reproduce the full-suite ordering or prove deployed key separation. The full-suite discrepancy remains unresolved and security-relevant.

## Reproduction and test-state correction

- Reconstructed the suite-class order for seed 40202 from the Rails/Minitest loader; all 335 failure/error classes in the recorded run appeared in that same relative order. `Visa::App::Oidc::LogoutsControllerTest` ran shortly before the JWKS separation case. Its setup installs one generated test key for multiple namespaces and reloads the registry; the shared test teardown restores ENV but did not reload that registry.
- Running the logout route test followed by the JWKS separation test in one process reproduced the same JWKS failure: two runs, 15 assertions, one failure. Added test teardown to restore the saved ENV and reload the registry. Repeating the same ordered pair passed two runs and 25 assertions; running the complete logout controller test file with the separation test passed 41 runs and 236 assertions. RuboCop and scoped `git diff --check` passed for the changed test file.
- This establishes the reproduced test-state leak and its local correction; it does not establish deployed key separation. The full suite has not been repeated after this correction, and other test helpers may have independent shared-state problems.
