# PublicController CSRF Test

Extracted from `plans/active/public-controller-base-plan.md` during archive.

## Problem

The plan specified that `protect_from_forgery` must be verified: a `POST` to a public endpoint
without a CSRF token should receive a 4xx response. These tests were not written during the initial
implementation.

## Acceptance

For each of the three `PublicController` bases (`Acme::PublicController`, `Sign::PublicController`,
`Jump::PublicController`):

- A test-only `POST` route (or an existing POST that hits the base) returns 4xx when no CSRF token
  is sent.
- Assert the response is a CSRF-related 4xx (typically 422 or 400).

Do not add production routes just for the test. Use an existing POST endpoint or a test helper that
exercises the forgery protection directly.

## Related

- `app/controllers/acme/public_controller.rb`
- `app/controllers/sign/public_controller.rb`
- `app/controllers/jump/public_controller.rb`
