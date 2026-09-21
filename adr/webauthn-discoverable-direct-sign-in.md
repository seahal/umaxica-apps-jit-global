# Discoverable credentials for direct app and com Passkey sign-in

* Status: Accepted
* Date: 2026-09-20
* Scope: UMAXICA app and com direct Passkey sign-in

## Context

The former app and com direct Passkey options flow accepted an identifier and returned a padded
`allowCredentials` list. The list exposed real credential IDs and could be compared across requests
or distinguished by length. This made account and Passkey existence observable before a WebAuthn
assertion was verified.

## Decision

App and com direct Passkey sign-in uses a discoverable, usernameless ceremony:

1. The options request does not require or use an identifier for account selection.
2. The options response contains no real credential descriptors; `allowCredentials` is empty or
   omitted according to the WebAuthn serializer contract.
3. The challenge remains bound to the session, surface, RP ID, origin, purpose, TTL, and one-time
   consumption rules, but has no actor binding at issuance.
4. Verification resolves the surface-local Passkey row by assertion credential ID and verifies the
   assertion with the saved public key. The browser `userHandle`, submitted identifier, and client
   metadata are not identity authorities.
5. Existing credential, actor, verified-PII, session-limit, restricted-session, UV, RP/origin,
   sign-count, risk, and audit checks remain in the verification path.
6. App and com registration require `residentKey: "required"` and `userVerification: "required"`.
   Org registration retains its current resident-key policy.
7. Existing non-discoverable app/com credentials are intentionally not migrated or accepted through
   a compatibility path. Re-registration is required.

Org normal sign-in remains bound to the Entra-selected Operator. Org Emergency, MFA, and Step-Up
remain actor-known ceremonies and retain their existing descriptor and policy contracts. The
actor-bound padding helper remains available only where those ceremonies require it; it is not used
by direct app/com options.

## Alternatives rejected

- Making dummy credential IDs deterministic or changing their lengths: this retains the disclosure
  surface and makes the obsolete identifier-first design more complex.
- Keeping old and discoverable flows in parallel: this would preserve the old enumeration path and
  create ambiguous registration compatibility semantics.
- Making org or actor-known ceremonies discoverable without a separate decision: this would change
  their established actor-binding security contract.

## Consequences

App/com users must use discoverable credentials registered after this change. No database migration
can convert a previously non-discoverable authenticator credential, so old app/com credentials need
re-registration. Turnstile, CSRF, rate limits, challenge binding, UV, and verification controls
remain required. The direct options endpoint no longer performs account lookup, which removes the
credential-disclosure boundary rather than trying to hide it with padding.
