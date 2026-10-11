# RP Session lock-order hardening evidence

- Date: 2026-09-17 UTC
- Branch: `feature`
- Parent commit: `dfb066a02d`
- Working tree: pre-existing `README.md` modification and `misc.md`/`refactor.md` deletions were
  preserved and were not staged.

## Implemented check

`RpSessionRevoker` now locks a Base Browser Session before selecting and locking its currently
usable RP Sessions. Child rows are selected in ascending primary-key order. This matches the OIDC
exchange path, which locks the parent before checking or creating a child, and removes the
child-before-parent deadlock order from browser-session revocation.

The regression test observes the public revocation operation's PostgreSQL row-lock statements and
requires the parent lock to precede a child lock. It does not replace database locking with mocks.

## Verification

- `ruby -c app/operations/rp_session_revoker.rb`: passed.
- `ruby -c test/operations/rp_session_revoker_test.rb`: passed.
- `bundle exec rubocop app/operations/rp_session_revoker.rb test/operations/rp_session_revoker_test.rb`:
  passed; 2 files, no offenses.
- The affected Rails test command was attempted with isolated test Valkey variables:
  `bundle exec bin/rails test test/operations/rp_session_revoker_test.rb`. It was blocked before
  assertions because PostgreSQL host `primary` could not be resolved.

## Not verified

The PostgreSQL lock-order assertion, concurrent exchange/revocation behavior, and transaction
rollback remain unverified until the isolated PostgreSQL test service is available. No production or
shared datastore was used.

## Follow-up verification

- Date: 2026-09-17 UTC
- The available isolated surface databases and explicit loopback test Valkey URLs supported the
  focused Rails run; no migration or datastore reset was performed.
- `bundle exec bin/rails test test/operations/rp_session_revoker_test.rb test/services/oidc_refresh_token_issuer_surface_test.rb`
  — passed, 10 runs / 66 assertions.
- The SQL observer matcher was corrected to accept Rails' application comment after `FOR UPDATE`.
  This was a regression-test observation fix only; the parent-before-child production lock order
  remains unchanged.

Independent concurrent exchange/revocation behavior, rollback under a forced failure, worker
execution, and external OIDC delivery remain outside this focused result.
