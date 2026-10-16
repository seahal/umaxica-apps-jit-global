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
- AUTH-6: The Device sign-in mock is retired: `/sign/in/device` reaches no controller and sign-in
  selection offers no device option, while the remaining sign-in methods keep working.
- AUTH-7: Base and Auth require a valid CSRF token on state-changing requests, including JSON and
  same-origin requests with Fetch Metadata. A missing or invalid token or an origin mismatch is
  refused before any update or flow issuance. Protocol callbacks keep their own state, nonce, PKCE
  and signature checks, and passing through Jump exempts nothing.

Sources: [authentication contract](../../.agents/harnesses/rules/generic/authentication-boundaries.mdc),
[Base/Auth authority](../../adr/base-auth-ceremony-and-seven-rp-boundary.md).
Broader scenarios: [identity authority regression checklist](../qa/identity-authority-regression-checklist.md).
