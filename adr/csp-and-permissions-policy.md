# CSP And Permissions-Policy

## Status

Accepted on 2026-04-10.

## Context

GitHub issues `#231` and `#266` tracked browser response header hardening for the application. The
goal was to keep browser feature access and inline asset execution constrained across all surfaces.

## Decision

The application uses both:

- Content Security Policy with nonce-based script protection
- Permissions-Policy with unused browser features denied and WebAuthn allowed
- Cross-origin isolation headers where they are compatible with the application's external assets

Security header changes should preserve an A+ result on both:

- Mozilla / MDN HTTP Observatory: `https://developer.mozilla.org/en-US/observatory`
- SecurityHeaders.com: `https://securityheaders.com/`

The implemented configuration is:

- CSP in `config/initializers/content_security_policy.rb`
- Permissions-Policy, COEP, COOP, and CORP in `config/initializers/permissions_policy.rb`

## Evidence

- `config/initializers/content_security_policy.rb` defines policy directives and nonce support.
- `config/initializers/permissions_policy.rb` denies unused features such as camera, geolocation,
  microphone, and USB.
- `config/initializers/permissions_policy.rb` allows the scanner-compatible WebAuthn directive
  `publickey-credentials-get`.
- `config/initializers/permissions_policy.rb` emits `Cross-Origin-Embedder-Policy`,
  `Cross-Origin-Opener-Policy`, and `Cross-Origin-Resource-Policy`.
- Turnstile views use CSP nonce support for inline scripts.

## Consequences

- The response header policy is explicit and reviewable in code.
- Future changes to browser feature access should update the initializers and add regression tests.
- Future changes to browser security headers should be checked against the Observatory and
  SecurityHeaders.com A+ target before release.

## Related

- Former plan: GH issue #231
- Former plan: GH issue #266
