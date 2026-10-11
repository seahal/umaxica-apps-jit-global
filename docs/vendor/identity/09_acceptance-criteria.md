---
title: Identity Acceptance Criteria
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

# Purpose

Define the acceptance criteria for reviewing identity docs and current implementation evidence.

# Scope

These criteria are for documentation review and implementation review.

# Non-scope

This task does not require test changes.

# Source Evidence

- `docs/vendor/identity/01_current-architecture.md`
- `docs/vendor/identity/02_responsibility-boundary.md`
- `docs/vendor/identity/03_route-endpoint-inventory.md`
- `docs/vendor/identity/04_cookie-session-token-matrix.md`
- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/06_failure-taxonomy.md`
- `docs/vendor/identity/07_social-linking-policy.md`
- `docs/vendor/identity/08_threat-model.md`
- `test/integration/routes/*`

# Current Decisions

- Acceptance can cite route contracts, sequence docs, and ADRs.
- Missing tests should be marked as gaps rather than silently assumed.

| ACC ID  | Area                                     | Acceptance Criterion                                                                                        | Evidence Required                                   | Test / Doc Link                                                                                              | Owner                  | Status                                             |
| ------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------- | -------------------------------------------------- |
| ACC-001 | route contract acceptance                | Route files and route contract tests agree on the current identity route families.                          | Route files and route tests.                        | `config/routes/*.rb`, `test/integration/routes/*.rb`                                                         | Implementation team    | Pass / gap where untested                          |
| ACC-002 | OAuth/OIDC endpoint ownership acceptance | Acme is the only Authorization Server and owns `/oauth/*` and `.well-known` metadata.                       | Route files, discovery stability test, ADRs.        | `config/routes/acme.rb`, `test/integration/routes/oidc_discovery_route_stability_test.rb`                    | Implementation team    | Pass                                               |
| ACC-003 | social callback boundary acceptance      | Social provider callbacks are distinct from OIDC callbacks and are not treated as OAuth token issuance.     | Route files and social boundary docs.               | `config/routes/sign.rb`, `docs/security/social-callback-boundary.md`                                         | Implementation team    | Pass / gap where ambiguous                         |
| ACC-004 | sign-in flow acceptance                  | Sign-in flows show the current ceremony boundaries and authority handoff.                                   | Sign-in sequence doc and route contract.            | `docs/security/sign-in-sequence.md`, `test/integration/routes/sign_route_contract_test.rb`                   | Implementation team    | Pass / gap where branch not covered                |
| ACC-005 | sign-up flow acceptance                  | Sign-up flows show the current ceremony boundaries, checkpoint behavior, and handoff.                       | Sign-up sequence doc and route contract.            | `docs/security/sign-up-sequence.md`, `test/integration/routes/sign_route_contract_test.rb`                   | Implementation team    | Pass / gap where branch not covered                |
| ACC-006 | sign-out/logout acceptance               | Browser logout remains a ceremony UI on multiple hosts, while authority remains Acme.                       | Logout sequence doc and route contracts.            | `docs/security/logout-sequence.md`, route tests                                                              | Implementation team    | Pass                                               |
| ACC-007 | OTP acceptance                           | OTP flows are protected by challenge expiry, retry handling, and anti-automation controls.                  | OTP-related docs and route evidence.                | `docs/security/turnstile.md`, `docs/security/sign-in-sequence.md`, `docs/security/sign-up-sequence.md`       | Implementation team    | Pass / gap where per-flow tests missing            |
| ACC-008 | passkey/WebAuthn acceptance              | Passkey flows have challenge/verification boundaries and replay awareness.                                  | Credential gateway docs and route evidence.         | `docs/security/credential-gateway.md`, sign route contract                                                   | Implementation team    | Pass / gap where specific replay test missing      |
| ACC-009 | social linking acceptance                | Social linking uses provider subject as the identity key and does not auto-link by email.                   | Social linking policy docs and evidence.            | `docs/vendor/identity/07_social-linking-policy.md`                                                           | Implementation team    | Pass                                               |
| ACC-010 | session limitation acceptance            | Session limitation is Acme-owned and surfaced through the documented limitation flow.                       | Acme route contract and sign-in sequence docs.      | `config/routes/acme.rb`, `docs/security/sign-in-sequence.md`                                                 | Implementation team    | Pass / gap where UI not centralized                |
| ACC-011 | session revocation acceptance            | Session revocation remains authority-bound to Acme even when the UI host varies.                            | Logout and session-token authority docs.            | `docs/security/logout-sequence.md`, `docs/security/session-token-authority.md`                               | Implementation team    | Pass                                               |
| ACC-012 | cookie/session/token matrix acceptance   | The matrix distinguishes authority, issuer, consumer, transport, and revocation.                            | This package plus authority docs.                   | `docs/vendor/identity/04_cookie-session-token-matrix.md`                                                     | Implementation team    | Pass                                               |
| ACC-013 | CSRF/CSP/rate limit/Turnstile acceptance | Browser mutation controls are present and do not replace auth or authorization.                             | Security header, Turnstile, and observability docs. | `docs/security/security-headers.md`, `docs/security/turnstile.md`, `docs/security/observability-boundary.md` | Implementation team    | Pass / gap where route-specific proof missing      |
| ACC-014 | audit/security logging acceptance        | Security-relevant events are recorded in durable audit/security records or clearly documented telemetry.    | Observability boundary docs.                        | `docs/security/observability-boundary.md`                                                                    | Implementation team    | Pass / gap where a durable record is not evidenced |
| ACC-015 | failure taxonomy acceptance              | All ceremony docs can be mapped to the shared failure taxonomy.                                             | Failure taxonomy doc and sequence docs.             | `docs/vendor/identity/06_failure-taxonomy.md`                                                                | Implementation team    | Pass                                               |
| ACC-016 | vendor docs acceptance                   | The vendor package is English-only, evidence-based, and current-vocabulary only.                            | Vendor docs and repo evidence.                      | `docs/vendor/identity/*.md`                                                                                  | Internal architecture  | Pass                                               |
| ACC-017 | third-party security review acceptance   | A vendor can trace every authority boundary, route family, and key threat without reading application code. | Package plus cited evidence paths.                  | `docs/vendor/identity/*.md`                                                                                  | Security vendor / SIer | Pass / gap if evidence absent                      |

# Open Questions

- Whether any future security review should require direct controller/service evidence in addition
  to route and docs evidence.

# Related Documents

- `docs/vendor/identity/10_vendor-questions.md`
- `docs/vendor/identity/12_gap-risk-register.md`
