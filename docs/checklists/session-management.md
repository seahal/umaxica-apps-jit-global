# Session management

Applies to session establishment, pending sign-in and revocation on every supported surface.

- SESSION-1: A successful session-establishment result means committed session authority; pending
  sign-in and recorded authentication evidence do not masquerade as an issued session.
- SESSION-2: Cookies, current-resource state and success audit follow the committed establishment;
  a refusal or failed transaction does not produce success state.
- SESSION-3: Root-login cooldown uses the root-login establishment anchor, not refresh, step-up or
  RP connection times; refusal does not disclose account existence or the remaining interval.
- SESSION-4: Issuance and revocation failures remain failures; database errors are not treated as
  absent sessions or successful revocations.
- SESSION-5: On token and preference DBSC refresh endpoints, malformed Structured Field identifiers
  and identifiers that do not match the current record cannot issue or replace a challenge or set
  a cookie. HTTP strings are decoded once and response values are serialized with escaping.
- SESSION-6: DBSC operational logs retain no identifier, proof or challenge values, including
  prefixes. Malformed or out-of-range proof timestamps produce explicit refusals.

- SESSION-7: Across all surfaces, application-signed and encrypted messages accept JSON only.
  Authenticated Marshal payloads are refused without a legacy-reader fallback
  ([message serializer configuration](../../config/application.rb)).

Sources: [root-login boundary](../../adr/root-login-establishment-boundary.md),
[session issuance rule](../../.agents/harnesses/rules/project/session-issuance.mdc).
The [DBSC header boundary](../architecture/dbsc.md#http-header-boundary) owns the wire contract.
Implementation paths and test inventory remain in those sources; this list records no test result.
