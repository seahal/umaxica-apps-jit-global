# Full test-suite verification

## Scope

Ran the complete Rails and Vitest suites on 2026-09-04 after preparing the production-shaped staging
object-storage configuration.

## Initial result

`pnpm test` passed immediately:

```text
Test Files: 84 passed
Tests: 1,020 passed
```

The first `bin/rails test` run completed with 12,341 runs, 70,375 assertions, four failures, two
errors, and one skip. The six non-passing cases were stale health-route expectations and one
development Compose alias contract mismatch:

- two tests still called plural health route helpers after the routes became singular resources;
- three assertions expected format-suffixed text health paths to resolve, contrary to the current
  documented contract that rejects those suffixes;
- Compose advertised aliases that no configured public URL or Host Authorization rule accepted.

The tests were aligned with the existing health endpoint contract, and the unused, unauthorized
Compose aliases were removed. The focused set then passed with 51 runs and 5,493 assertions.

## Final result

Command:

```bash
bin/rails test
```

Result:

```text
12,341 runs
70,590 assertions
0 failures
0 errors
1 skip
```

The remaining skip was identified with:

```bash
bin/rails test test/integration/oidc_rp_browser_flow_test.rb:345 --verbose
```

It is the existing `OidcRpBrowserFlowTest` case for the app email sign-in session-limit handoff,
explicitly blocked on repository issue 846. It was not treated as a passing test or removed as part
of this unrelated verification.

Targeted RuboCop checks for the four adjusted test files reported no offenses, and
`git diff --check` reported no whitespace errors.
