# WU-42: `redirect_uri` and authorization-request conformance

- Date: 2026-10-23. Base commit `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`; change uncommitted.
- Decisions: D-145, D-146, D-147 (N-1 … N-4), D-148 (N-5), D-149 (N-6).
  ADR: `adr/oidc-authorization-request-profile.md`.

## Change

- `OidcAuthorizeRequestResolver` validates in the D-147 order: `client_id` (present, registered),
  `redirect_uri` (present, exact match) — both stay local errors — then `response_type`
  (`unsupported_response_type`), `openid`, scope allow list (`invalid_scope`), `prompt`, PKCE
  (`code_challenge` must be 43 base64url characters, S256), `max_age`, `state`/`nonce`, resource
  (`access_denied`). Typed errors: `RequestError` (redirected, with `error`), `UnsupportedPrompt`
  (direct 400). Both subclass `ArgumentError`, so other callers keep refusing.
- `OidcAuthorizationRequestErrors` (new concern, included by the three Base authorize controllers):
  `RequestError` → redirect to the registered `redirect_uri` with `error`, `state` (when sent) and
  `iss`; `UnsupportedPrompt` → 400 JSON `invalid_request` naming `prompt`.
- `OidcAuthorizeCoordinator.rp_redirect_url` appends the encoded response parameters to the
  registered string without reparsing it (N-2).
- Token endpoint: `redirect_uri` / `client_id` mismatch, an unregistered stored `redirect_uri` and a
  well-formed non-matching `code_verifier` → `invalid_grant`; a missing or malformed verifier and a
  non-S256 stored method stay `invalid_request` (N-3).
- `OidcClientStoresStaticClientStore` validates every built `redirect_uri` (absolute, host, no
  fragment, no userinfo, https in production, no reserved query key) and raises at build (N-4).
- Discovery advertises `prompt_values_supported` from the resolver's per-realm table (N-5).
- Tests that pinned the earlier local JSON 400 for post-validation errors, or used an invalid
  `code_challenge` literal (`"challenge"`, `"a"`, …) for unrelated cases, were updated; each renamed
  test states the new contract.

## Verification

- New `test/controllers/base/oauth_redirect_uri_conformance_test.rb`: exact-match partitions incl.
  `:443`, `:3001`, trailing slash, case, added query, fragment, other realm, missing (A42-2);
  invalid URI combined with other errors (A42-3, A42-9); post-validation errors redirected (A42-8);
  unsupported/combined `prompt` direct 400 (A42-12); `code_challenge` 42/44/padding/`+`/`/`
  (A42-13); Discovery per realm (A42-11); registered query kept (A42-10). 7 runs, 113 assertions, 0 failures.
- All 215 test files touching authorize, token, Discovery or the coordinators: 2148 runs,
  43 failures, 0 errors — every failure is in the G-1 baseline list; no new failure.
- Development boot with the real registrations passes the N-4 validation.
- **Not run:** A42-5 negative boot (no way to inject an invalid registration without editing
  configuration), A42-6 (Jump integration, D-146).
