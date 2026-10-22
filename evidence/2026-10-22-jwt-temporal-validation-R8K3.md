# JWT temporal validation and Apple signature contracts

- Date: 2026-10-22.
- Revision: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2`.
- Worktree: uncommitted changes, including the JWT option corrections, new temporal tests,
  Apple signature contracts and ADR, affected these results. Unrelated pre-existing work was
  preserved. No production request, key rotation or provider network call was performed.
- Decision: [JWT validation and key risks](../adr/jwt-validation-and-key-risk-decisions.md).

## Verification

The following command passed: **232 runs, 1059 assertions, 0 failures, 0 errors, 0 skips**
(seed 41827).

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/values/jwt_temporal_validation_test.rb \
  test/contracts/omniauth_apple_strategy_contract_test.rb \
  test/adapters/oidc_op_protocol_verifiers_test.rb \
  test/values/security_jwt_access_token_negative_cases_test.rb \
  test/values/security_jwt_rfc9068_access_token_profile_test.rb \
  test/values/security_jwt_auth_access_token_codec_failures_test.rb \
  test/values/security_jwt_preference_token_codec_claims_test.rb \
  test/services/oidc/id_token_verifier_test.rb \
  test/services/oidc_client_assertion_jwt_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/oidc_token_revoker_surface_lookup_test.rb \
  test/controllers/concerns/authentication/token_service_test.rb \
  test/integration/oidc_rp_logout_binding_partitions_test.rb \
  test/services/oidc_access_jwt_child_revoke_independence_test.rb
```

After correcting test formatting, the two changed test files were rerun with
`PARALLEL_WORKERS=1 bin/rails test test/values/jwt_temporal_validation_test.rb test/contracts/omniauth_apple_strategy_contract_test.rb`:
**17 runs, 96 assertions, 0 failures, 0 errors, 0 skips** (seed 6265).

`bundle exec rubocop` on the seven changed application Ruby files and those two test files passed:
**9 files inspected, no offenses detected**. The initial lint run reported formatting offenses in
the added tests; those were corrected before the successful run. `git diff --check` passed.

## Observations and limits

- Frozen-clock tests cover `iat` and `nbf` at now +29/+30/+31 seconds and `exp` at
  now -29/-30/-31 seconds for Auth/Preference access, shared OIDC ID and separated-RP Access,
  ID and Logout tokens. Client assertions cover the +29/+30/+31-second `iat` boundary.
- An expired access token is rejected by normal authentication decoding and decoded by the
  explicit expired-access path. The latter still rejects a wrong issuer, wrong audience,
  future `nbf`/`iat` beyond leeway, a missing `exp`, and a different signing key.
- Apple RS256 and RS512 each succeed with a trusted synthetic key and fail with a different
  signing key, through the strategy's public authentication interface. Only the external JWKS
  fetch boundary is stubbed; the token signature and claims are verified by the dependency.
- No Apple algorithm restriction was added. The full repository suite was not run in this
  change. The earlier audit's three COM/ORG authorization-continuation failures were outside this
  selected run and remain unresolved; no claim is made that this change fixes them.
- Deployed key isolation and `secret_key_base` disclosure/rotation were not tested. Rotation is
  an accepted operational response, not an action performed in this session.
