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

Sources: [root-login boundary](../../adr/root-login-establishment-boundary.md),
[session issuance rule](../../.agents/harnesses/rules/project/session-issuance.mdc).
Implementation paths and test inventory remain in those sources; this list records no test result.
