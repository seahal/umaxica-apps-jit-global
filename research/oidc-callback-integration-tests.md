# OIDC Callback Integration Tests Note

This note records the callback coverage added for the Acme relying-party surfaces.

## Status

Completed on 2026-04-07.

## Context

The callback concern is shared across Acme, Core, and Docs surfaces. The plan focused on proving
real callback behavior for the Acme surfaces first.

## Evidence

- `test/controllers/acme/app/auth/callbacks_controller_test.rb`
- `test/controllers/acme/org/auth/callbacks_controller_test.rb`
- `test/controllers/acme/com/auth/callbacks_controller_test.rb`
- `test/support/oidc_callback_test_helper.rb`

## Verified Behavior

- valid `state` is accepted
- `Oidc::TokenExchangeService.call(...)` receives the expected PKCE / OIDC parameters
- auth cookies are written from the token response
- session callback state is consumed
- redirect falls back to `/` when `oidc_return_to` is absent
- mismatched `state` is rejected
- token exchange failure redirects to `/` and sets the expected alert
- callback URL construction preserves host and port rules

## Validation

- `bundle exec rails test test/controllers/acme/app/auth/callbacks_controller_test.rb test/controllers/acme/org/auth/callbacks_controller_test.rb test/controllers/acme/com/auth/callbacks_controller_test.rb`
  passes

## Consequences

- Acme callback integration coverage is complete enough to leave `plans/active/`.
- The same helper can be reused when Core and Docs callback coverage becomes the next target.
