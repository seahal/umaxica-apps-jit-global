# Curfew-capped authorization code

HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree contained uncommitted changes affecting this check.

- `PARALLEL_WORKERS=1 bin/rails test test/services/oidc/token_exchange_service_test.rb:208`: 1 run, 7 assertions, no failures, errors or skips. An admitted transaction's authorization-code expiry was at or before its curfew; exchange at that expiry returned `invalid_grant` while the stored code remained issued.
- `bundle exec rubocop test/services/oidc/token_exchange_service_test.rb --format simple`: no offenses.
- `bundle exec rubocop test/integration/admission_curfew_test.rb --format simple`: no offenses after the final clock-control adjustment recorded in `2026-10-27-cycle-curfew-boundary-Q5F8.md`.

Other carried values and method-specific ceremony TTLs were not exercised by this check; A06-5 remains partial.

Documentation discrepancy found while mapping the remaining lifetimes: `two.md` says the sign-up Flow lifetime uses its own TTL rather than the curfew (line 711), while `SignUpFlowTicket` caps a newly created Flow's `expires_at` at its Admission Binding curfew. This observation is from code inspection, not a new runtime test.
