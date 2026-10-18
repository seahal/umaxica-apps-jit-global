# Ceremony unverified-payload hardening

Date: 2026-09-19

## Findings addressed

A review of the identity ceremony JWT contracts found no signature bypass or cross-surface path, but
three weaknesses in how claims were read before verification:

1. `decode_unverified_payload` (step-up, email, telephone, TOTP, passkey, secret credential) and
   `decode_untrusted_routing_payload` (social) accepted any JSON payload. A token whose payload was
   `[1]` or `5` raised an uncaught `TypeError` at `payload["surface"]`, which surfaced as HTTP 500.
   Observed before the fix with `bundle exec ruby -rjwt`: arrays and integers raised `TypeError`; a
   JSON string payload returned a substring from `String#[]`.
2. `BaseStepUpCompletion#complete_step_up_ceremony!` looked up the step-up transaction with the
   unverified `transaction_id` before the signature was checked.
3. `IdentityStepUpCeremonyFreshnessCommitter` chose its verification `issuer_id` from the unverified
   `surface` claim, unlike every other ceremony committer, which takes `surface:` from the caller.

## Changes

- All seven contracts raise their contract `Error` unless the unverified payload is a Hash.
- Step-up completion verifies the result against the controller's own surface key first, then looks
  up the transaction with the signed `transaction_id`.
- The freshness committer takes `surface:` from the caller and rejects a result whose surface differs.

## Verification

- `bin/rails test` over the 190 test files referencing step-up ceremonies, the ceremony contracts,
  or verification completion: 1664 runs, 0 failures, 0 errors, 1 skip. The skip is the existing
  `test/integration/oidc_rp_browser_flow_test.rb:129` (issue 846).
- Regression check: with the contract and completion changes reverted, the new tests failed
  (`decode_unverified_payload rejects a token whose payload is not a JSON object` for step-up and
  email, and `app base completion rejects a result whose payload is not a JSON object`).
- The committer surface-mismatch test fails with `kid is unknown`, confirming that the signing keys
  are separated per issuer.
- `bundle exec rubocop` on the changed files: no offenses.
