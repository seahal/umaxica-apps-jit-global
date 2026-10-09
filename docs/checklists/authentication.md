# Authentication

Applies to browser authentication on each supported surface; method availability remains
surface-specific. These are durable requirements, not current verification results.

- AUTH-1: State-changing browser requests retain Rails CSRF, Origin and Fetch Metadata protection;
  ceremony binding adds protection rather than replacing it.
- AUTH-2: A browser-bound ceremony refuses stale, mismatched, cross-browser and replayed admission.
- AUTH-3: Missing or contradictory authentication evidence produces an explicit refusal, without
  inferring another actor, credential, browser or assurance level.
- AUTH-4: Auth supplies ceremony continuity, not an independent general login session or authority
  token issuer; preserve the explicitly accepted admission-binding exception.
- AUTH-5: App Apple/Google link completion requires a live Ticket grant. A callback or grant begun
  before Source unlink or account termination cannot authenticate a later owner, reattach or sign up
  the released subject;
  the release proof survives removal of the app identity row. Org Microsoft Entra ID is company-owned
  and is not automatically unlinked by app account withdrawal.

Sources: [authentication contract](../../.agents/harnesses/rules/generic/authentication-boundaries.mdc),
[Base/Auth authority](../../adr/base-auth-ceremony-and-seven-rp-boundary.md).
Broader scenarios: [identity authority regression checklist](../qa/identity-authority-regression-checklist.md).
