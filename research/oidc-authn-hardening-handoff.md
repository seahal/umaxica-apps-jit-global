# OIDC AuthN Hardening Handoff Note

This note records the implementation state described by the OIDC auth hardening spec.

## Status

Completed on 2026-04-07.

## Context

The spec tracked three concrete areas:

- fail-fast `Current.actor` and `Current.actor_type`
- OIDC claim alignment for `subject_type`, `acr`, and `amr`
- attacker-oriented acceptance coverage

## Evidence

- `app/models/current.rb` rejects invalid actor and actor_type assignments.
- `app/services/auth/token_claims.rb` normalizes `subject_type`, `acr`, and `amr`.
- `app/services/auth/token_service.rb` requires the OIDC claims set used by the current contract.
- `app/services/oidc/token_exchange_service.rb` issues `id_token` values with `subject_type`, `sid`,
  `nonce`, `acr`, `amr`, and `jti`.
- `test/unit/current/current_attributes_test.rb`, `test/services/auth/token_claims_test.rb`,
  `test/services/auth/token_service_test.rb`, `test/services/oidc/token_exchange_service_test.rb`,
  and `test/controllers/acme/app/auth/callbacks_controller_test.rb` cover the hardening path.

## Validation

- `bundle exec rails test test/unit/current/current_attributes_test.rb test/services/auth/token_claims_test.rb test/services/auth/token_service_test.rb test/services/oidc/token_exchange_service_test.rb test/controllers/acme/app/auth/callbacks_controller_test.rb`
  passes.

## Consequences

- The hardening memo can leave `plans/active/`.
- The callback integration test plan remains active and should continue separately.
