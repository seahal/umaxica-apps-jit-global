---
title: Social Linking Policy
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

Document the current social account linking rule.

# Scope

This applies to social sign-in and social sign-up flows.

# Non-scope

This does not define provider-specific UI copy.

# Source Evidence

- `docs/security/social-callback-boundary.md`
- `docs/security/sign-in-sequence.md`
- `docs/security/sign-up-sequence.md`
- `config/routes/sign.rb`
- `test/integration/routes/sign_route_contract_test.rb`
- `app/services/social_auth_link_handler.rb`
- `app/services/social_auth_verified_provider_assertion.rb`
- `app/services/social_auth_uid_extractor.rb`

# Current Decisions

- Provider + subject is the identity key.
- Email match alone must not automatically link accounts.
- Verified email match alone must not automatically link accounts.
- Explicit user-confirmed linking is required.
- Account linking must not occur from an unauthenticated ambiguous state.
- Conflicts must fail closed or require safe confirmation.

| Scenario                                             | Required Behavior                                                    | Security Reason                                        | UX Requirement                                                         | Evidence / Test                             |
| ---------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------- | ------------------------------------------- |
| Provider subject matches existing account            | Continue the existing account flow.                                  | Subject is the stable identity key.                    | Show the expected continuation path.                                   | route contracts                             |
| Email matches but provider subject does not          | Do not auto-link.                                                    | Email alone is not an identity key.                    | Ask for safe confirmation or restart.                                  | social boundary docs                        |
| Verified email matches but provider subject does not | Do not auto-link.                                                    | Verified email still does not prove account ownership. | Ask for safe confirmation or restart.                                  | `docs/security/social-callback-boundary.md` |
| Provider relay email is missing                      | Do not auto-link from absence of email.                              | Missing email is not evidence of equivalence.          | Continue with the provider subject path or safe confirmation.          | `docs/security/social-callback-boundary.md` |
| Provider relay email changed                         | Do not auto-link solely from the changed email.                      | Email churn is not proof of ownership transfer.        | Show a safe confirmation or fail closed.                               | `docs/security/social-callback-boundary.md` |
| Provider relay email is unverified                   | Do not auto-link.                                                    | Unverified email is weaker than subject.               | Ask for safe confirmation or restart.                                  | `docs/security/social-callback-boundary.md` |
| Private relay email is present                       | Keep subject as the key; treat relay email as transport detail only. | Relay addresses are not stable identity.               | Avoid exposing the relay address as authority.                         | `docs/security/social-callback-boundary.md` |
| Unauthenticated ambiguous state                      | Fail closed or require explicit safe confirmation.                   | Ambiguous state is a takeover risk.                    | Show a clear but non-leaking next action.                              | `docs/security/social-callback-boundary.md` |
| User explicitly confirms linking                     | Link only after confirmation and evidence checks.                    | User confirmation closes the ambiguity.                | Keep the confirmation step understandable and reversible until commit. | `config/routes/sign.rb`, route tests        |

## Audit Expectations

- Record social linking attempts as security-relevant events.
- Do not log raw provider assertions, tokens, or email values.
- Record whether the action was link, unlink, conflict, or rejection.

## UX Expectations

- Keep successful linking lightweight.
- On conflict, give safe next steps without disclosing attacker-useful details.
- Do not silently link accounts based on email similarity.

## Acceptance Criteria

- Provider subject remains the identity key.
- Email match alone does not link accounts.
- Verified email match alone does not link accounts.
- Explicit user-confirmed linking is required.
- Ambiguous unauthenticated states fail closed or require safe confirmation.

# Open Questions

- Whether any provider-specific edge case requires a dedicated confirmation path.

# Related Documents

- `docs/vendor/identity/05_authentication-flow-inventory.md`
- `docs/vendor/identity/08_threat-model.md`
- `docs/vendor/identity/11_decision-register.md`
