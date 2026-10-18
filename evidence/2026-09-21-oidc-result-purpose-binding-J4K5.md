# OIDC result-purpose binding

Date: 2026-09-21 UTC

## Finding and change

The Base OIDC result endpoint previously attempted every result-purpose namespace until a Valkey
record matched. A purpose-mismatched result carrying the expected surface and transaction reference
could therefore be consumed before the authorization transaction's later state checks rejected it.

The endpoint now resolves the authorization transaction first and passes its server-side intent to
the result consumer. Valkey consumption uses only the corresponding result purpose and atomically
checks the expected surface, actor type, and transaction reference. A mismatch is rejected without
consuming the opaque result. Base-local `local_sign_in` and `local_sign_up` admissions remain
isolated to Base's own landing entry and are not accepted as ordinary RP result purposes.

## TDD verification

The new integration test was run before the production change and failed because the mismatched
`invitation_result` reached the transaction-state response (`authorization transaction is not
ready`), proving that the result had been consumed. After the change:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/base/oauth_authorization_surfaces_test.rb \
  test/services/base_auth_admission_coordinator_test.rb \
  test/services/authentication_purpose_contract_test.rb
23 runs, 87 assertions, 0 failures, 0 errors, 3 skips
```

The focused skip count was unchanged from the existing suite. Static checks passed for the three
changed files, `git diff --check` passed, and the Frozen Plan ledger validator returned `PASS`.

The current full Rails regression run was:

```text
bin/rails test
11473 runs, 73294 assertions, 0 failures, 0 errors, 6 skips
```

No application configuration, external service, shared database, GitHub resource, or CSRF policy
was changed to obtain these results.
