# WU-11: JWKS refetch limit — lease death, real-store TTLs, request-level BCL outage

- Revision: `bde2346c17e2aa911acc95de1f6035f80498f2da`. The worktree held extensive uncommitted
  work by other agents (locales, refresh, logout); this change is uncommitted and touches only tests.
- Scope: the "Limits" of `2026-10-23-wu11-jwks-refetch-limit-J1K5.md` and
  `2026-10-25-wu11-concurrent-jwks-C1J8.md` (A11-8, A11-12 on the real store, BX-7 at request level),
  against `two.md` 6.3 (D-136, D-144). No application code changed: the implementation already met
  the decided behavior, so the new tests passed on first run (characterization, not Red → Green).

## Added

- `test/adapters/oidc_jwks_refetch_limiter_test.rb`: (A11-8) a lease holder that never records an
  outcome makes another limiter `busy`; the lease PTTL is in (9 000, 10 000] ms; after the real
  store expires the lease (1 ms PEXPIRE, polled until gone) the other limiter gets the lease.
  (A11-12, real store) the `last` record PTTL is in (29 000, 30 000] ms; while present another
  worker gets `window` with the recorded kids; after the store expires it, a lease is granted.
- `test/integration/rp_backchannel_logout_jwks_outage_test.rb` (new): a Logout Token with the OP's
  claims signed under an unpublished `kid`, with the JWKS GET failing (`Faraday::ConnectionFailed`
  through `OutboundHttpStub`) → 503, local session not revoked, no event receipt. Discrimination
  check (temporary, reverted): the same request with the JWKS reachable but lacking the `kid`
  answered 400 (1 run, 3 assertions, 0 failures).

## Observations

- `bin/rails test test/adapters/oidc_jwks_refetch_limiter_test.rb
  test/adapters/oidc_jwks_concurrent_lookup_test.rb test/adapters/oidc_op_protocol_verifiers_test.rb
  test/integration/rp_backchannel_logout_jwks_outage_test.rb
  test/integration/rp_backchannel_logout_receiver_test.rb test/services/rp_request_authenticator_test.rb
  test/values/jwt_temporal_validation_test.rb`: 40 runs, 250 assertions, 0 failures/errors/skips.
- `bundle exec rubocop` on the two test files: autocorrected layout only, then no offenses. After
  the autocorrect, the two files were run again: 10 runs, 46 assertions, 0 failures/errors/skips.

## Not done

- Failed self-fetch retries: when `last` is `ok` with the `kid`, a failed self-fetch returns
  `unavailable`, and the next request for that `kid` fetches again; nothing bounds these retries
  per process. `two.md` 6.3 records no decision on bounding them, so no change was made (open
  question for the owner).
