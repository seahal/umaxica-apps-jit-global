---
title: Identity Responsibility Boundary
status: draft
audience:
  - SIer
  - security-vendor
  - internal-architecture
  - implementation-team
owner: TBD
last-reviewed: TBD
source-of-truth: current-repository-evidence
confidentiality: internal-vendor-shareable
---

> **Current-contract supersession (2026-09-23):** The responsibility matrix below records the
> earlier Acme/Sign architecture. It is retained as vendor-review history and is not a current
> authority assignment. Use `adr/base-auth-ceremony-and-seven-rp-boundary.md` and
> `docs/security/session-token-authority.md` for the active contract: Base owns the physical OIDC
> IdP/Authorization Server, Browser Session, RP Session, and token authority; Auth owns ceremony
> continuity only; and the first-party browser RPs are surface-specific. Do not restore shared RP
> clients or Acme/Sign session authority from this matrix.

# Purpose

Define which surface owns each identity capability.

# Scope

This matrix covers authority, UI hosting, ceremony execution, and transport boundaries.

# Non-scope

It does not describe every controller implementation detail.

# Source Evidence

- `config/routes/acme.rb`
- `config/routes/sign.rb`
- `config/routes/core.rb`
- `config/routes/base.rb`
- `config/routes/palm.rb`
- `docs/identity/authority-boundary.md`
- `docs/security/session-token-authority.md`
- `docs/security/credential-gateway.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/logout-sequence.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `docs/security/turnstile.md`
- `docs/security/security-headers.md`

# Current Decisions

- UI host is not necessarily authority.
- Sign may host session-management UI but does not own session/token/protocol authority.
- Acme is the only Authorization Server.

| Capability                            | Acme | Sign | Core | Base | Palm | Browser | Internal Team | SIer | Security Vendor | Notes                                                           |
| ------------------------------------- | ---- | ---- | ---- | ---- | ---- | ------- | ------------- | ---- | --------------- | --------------------------------------------------------------- |
| OAuth authorization endpoint          | Y    | N    | N    | N    | N    | Y       | R             | I    | C               | Acme owns `/oauth/authorize`.                                   |
| OAuth token endpoint                  | Y    | N    | N    | N    | N    | N       | R             | I    | C               | Acme owns `/oauth/token`.                                       |
| OIDC userinfo                         | Y    | N    | N    | N    | N    | N       | R             | I    | C               | Acme owns `/oauth/userinfo`.                                    |
| JWKS/discovery                        | Y    | N    | N    | N    | N    | N       | R             | I    | C               | Acme owns `.well-known` protocol metadata.                      |
| OIDC logout                           | Y    | N    | N    | N    | N    | Y       | R             | I    | C               | Acme owns `/oidc/logout`.                                       |
| RP OIDC authorization request         | N    | N    | Y    | Y    | Y    | Y       | R             | I    | C               | RP start routes exist on Core/Base/Palm and Sign.               |
| RP OIDC callback                      | N    | N    | Y    | Y    | Y    | Y       | R             | I    | C               | Callback is RP-local, not AS-owned.                             |
| social provider callback              | N    | Y    | N    | N    | N    | Y       | R             | I    | C               | Sign hosts social ceremony callbacks.                           |
| sign-in ceremony UI                   | N    | Y    | N    | N    | N    | Y       | R             | I    | C               | Sign owns ceremony UI.                                          |
| sign-up ceremony UI                   | N    | Y    | N    | N    | N    | Y       | R             | I    | C               | Sign owns ceremony UI.                                          |
| sign-out ceremony UI                  | Y    | Y    | Y    | Y    | Y    | Y       | R             | I    | C               | UI can be hosted on multiple surfaces, authority still differs. |
| settings credential UI                | N    | Y    | Y    | Y    | N    | Y       | R             | I    | C               | Sign and Core/Base expose credential/session settings.          |
| session-management UI                 | Y    | Y    | Y    | Y    | N    | Y       | R             | I    | C               | Sign may host UI, but Acme owns the authority.                  |
| session authority                     | Y    | N    | Y    | Y    | N    | N       | R             | I    | C               | Acme owns session authority.                                    |
| token authority                       | Y    | N    | Y    | Y    | Y    | N       | R             | I    | C               | Acme owns token authority.                                      |
| cookie transport                      | Y    | Y    | Y    | Y    | Y    | Y       | R             | I    | C               | Host-local transport, not authority.                            |
| refresh behavior                      | Y    | N    | Y    | Y    | N    | N       | R             | I    | C               | Transparent refresh and refresh rotation are Acme-owned.        |
| OTP challenge                         | N    | Y    | N    | N    | N    | Y       | R             | I    | C               | Sign hosts OTP ceremony UI and validation.                      |
| passkey/WebAuthn challenge            | N    | Y    | N    | N    | N    | Y       | R             | I    | C               | Sign hosts passkey ceremony UI and validation.                  |
| rate limiting                         | Y    | Y    | Y    | Y    | Y    | N       | R             | I    | C               | Shared operational control, flow-specific enforcement.          |
| CSRF handling                         | Y    | Y    | Y    | Y    | Y    | Y       | R             | I    | C               | Browser mutation protection.                                    |
| CSP handling                          | Y    | Y    | Y    | Y    | Y    | Y       | R             | I    | C               | Browser security header boundary.                               |
| Turnstile                             | Y    | Y    | Y    | Y    | Y    | Y       | R             | I    | C               | Anti-automation control for browser mutations.                  |
| audit logging                         | Y    | Y    | Y    | Y    | Y    | N       | R             | I    | C               | Durable audit/security records are separate from app logs.      |
| security event handling               | Y    | Y    | Y    | Y    | Y    | N       | R             | I    | C               | Includes audit and abuse response paths.                        |
| support/operator action, if evidenced | Y    | Y    | Y    | Y    | N    | N       | R             | I    | C               | Operator-facing management exists where routes are evidenced.   |

# Open Questions

- Whether all UI hosts shown in the repository are intentional long-term hosts or compatibility
  hosts.
- Whether any future route should be reclassified from UI hosting to authority hosting.

# Related Documents

- `docs/vendor/identity/01_current-architecture.md`
- `docs/vendor/identity/03_route-endpoint-inventory.md`
- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/11_decision-register.md`
