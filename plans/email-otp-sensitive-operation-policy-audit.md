# Email OTP Sensitive-Operation Policy Audit

## Status

Deferred.

This work is intentionally outside the current authentication-assurance cleanup. Do not expand the current change into a repository-wide sensitive-operation policy audit.

## Context

Umaxica permits Email OTP to complete normal step-up on the APP and COM surfaces as an explicit product-specific reauthentication mechanism.

Email OTP:

* does not establish an achieved NIST Authentication Assurance Level;
* is not phishing-resistant;
* must not be promoted to AAL1, AAL2, or AAL3 merely because it completes normal step-up;
* is not available as an ORG step-up method.

Step-up completion, freshness, allowed method policy, achieved assurance, and phishing resistance are independent security properties.

AAL2 and AAL3 are currently reserved and unimplemented. Runtime paths must not treat either level as currently achievable.

## Deferred Question

Perform a repository-wide audit of sensitive operations and determine, operation by operation, whether normal step-up completed with Email OTP provides sufficient evidence for that operation.

The audit must not begin from the assumption that every existing Email OTP step-up use is either safe or unsafe. Each operation must be assessed from its actual security impact and threat model.

At minimum, review operations involving:

* authentication credential registration, replacement, revocation, and deletion;
* email and other contact-identifier changes;
* session and token revocation;
* account withdrawal or destructive account lifecycle transitions;
* recovery-related state;
* social identity linking and unlinking;
* authorization or ownership changes;
* security-sensitive organization or operator actions;
* any operation that can materially weaken subsequent authentication.

## Required Analysis

For each protected operation, determine independently:

1. whether fresh normal step-up is required;
2. whether Email OTP is an acceptable step-up method;
3. whether phishing resistance is required;
4. whether the operation should restrict `allowed_methods`;
5. what freshness window is appropriate;
6. what session, actor, scope, resource, purpose, and audience bindings are required;
7. whether additional authorization, approval, notification, cooldown, or recovery controls are necessary.

Do not use an AAL2 or AAL3 label as a substitute for defining these concrete requirements while those levels remain unimplemented.

## Deliverables

The future audit should produce:

* a canonical sensitive-operation policy matrix;
* tests that enforce each material boundary;
* documentation for intentional Email OTP allowances and prohibitions;
* ADR updates for decisions with security or architectural significance;
* removal of stale or contradictory documentation discovered during the audit.

Any finding that Email OTP is insufficient for a particular operation should be fixed in the same work or explicitly recorded as an accepted, bounded risk with rationale.

## Non-goals

This deferred audit is not required to complete the current AAL cleanup.

The current work may proceed with:

* AAL2 and AAL3 rejected as unsupported at runtime;
* normal step-up kept independent from achieved AAL;
* Email OTP retained for APP/COM normal step-up under the current documented product exception.

## Completion Criterion

This plan is complete when every security-sensitive operation has an explicit, tested step-up policy and no operation relies on an implicit assumption that “step-up completed” means “sufficient authentication strength.”

