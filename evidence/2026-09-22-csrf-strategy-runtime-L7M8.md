# CSRF strategy runtime revalidation

- Date: 2026-09-22 UTC
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: existing changes preserved; no controller or configuration change was made during this
  revalidation.
- External writes: none.

## Current contract

`ApplicationController` and the surface roots explicitly use Rails 8.2's
`header_or_legacy_token` verification strategy with `with: :exception`. The framework default
remains `header_only`; the application choice is explicit and is not a CSRF weakening. The only
reviewed exceptions are the server-to-server OIDC logout header-only endpoint and the bounded,
non-mutating CSP violation report receiver.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/security/invariants/csrf_verification_strategy_invariant_test.rb \
  test/unit/security/skip_forgery_protection_usage_test.rb \
  test/security/invariants/forbidden_patterns_invariant_test.rb
```

Result: `9 runs, 20 assertions, 0 failures, 0 errors, 0 skips`.

The verification confirms that controllers declare a strategy, the default failure behavior is
exception-based, the reviewed exceptions remain allowlisted, and no new null-session or
unreviewed forgery bypass is present.
