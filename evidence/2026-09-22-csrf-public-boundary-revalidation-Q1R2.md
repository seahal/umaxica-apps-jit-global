# Public CSRF Boundary Revalidation

Date: 2026-09-22

Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

The worktree contained pre-existing and concurrent uncommitted changes. This
verification did not reset, stash, stage, commit, or discard them. No external
service or shared/production data was accessed.

## Finding

The historical `public-controller-csrf-test` plan names
`Acme::PublicController`, `Sign::PublicController`, and
`Jump::PublicController`. Those classes are absent from the current checkout;
the plan's original class-specific acceptance is therefore stale. No
compatibility classes or production routes were added.

The active controller architecture has explicit Rails 8.2 CSRF strategy
declarations. The repository-wide invariant allows only the reviewed
header-only OIDC logout exception and the bounded CSP telemetry exception;
ordinary browser application endpoints retain the hybrid
`:header_or_legacy_token` strategy.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/base/public_controller_test.rb \
  test/controllers/auth/public_controller_test.rb \
  test/security/invariants/csrf_verification_strategy_invariant_test.rb \
  test/unit/security/skip_forgery_protection_usage_test.rb

20 runs, 38 assertions, 0 failures, 0 errors, 0 skips
```

The public boundary tests cover rejection of a cross-site unsafe request
without a token and acceptance with a valid token. The strategy and skip
allowlist tests cover the repository-wide declaration boundary. Rails forgery
protection was not disabled or weakened.

## Disposition

`ALREADY_SATISFIED` for the current security contract; the historical
controller-name requirement is `STALE_REQUIREMENT`. No production code change
was needed for this item.
