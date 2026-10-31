# WU-7 com JWT claim validation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; prior and current uncommitted changes were
  present during verification.
- Anonymous com decoding requires the closed claim set, nonempty string issuer, subject and jti,
  the com audience, and integer issuance and expiry times. Tests exercise signed extra claims and
  empty or wrongly typed subject and jti values.
- `bin/rails test test/values/anonymous_com_preference_token_shape_test.rb test/integration/anonymous_com_preference_write_journey_test.rb`:
  14 runs, 87 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop app/values/security_jwt_preference_token_codec.rb test/values/anonymous_com_preference_token_shape_test.rb`:
  2 files inspected, no offenses.
- This does not establish allowlisted preference values, realm key separation, the common write
  transaction or the remaining WU-7 acceptance criteria.
