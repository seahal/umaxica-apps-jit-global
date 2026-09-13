# Three-provider authentication hardening implementation notes

## Context

- Original request: destructive pre-deployment consolidation of Apple, Google, and Microsoft Entra
  ID authentication.
- Related decisions: `adr/org-entra-id-sign-in-boundary.md` and
  `docs/operations/entra-org-login-runbook.md`.
- Implementation date: 2026-07-31.

## Decisions made during implementation

- Google identity now comes only from a locally verified OIDC ID token. The strategy boundary
  verifies RS256, Google JWKS, issuer, audience, expiry, issuance time, and one-time nonce. It does
  not call UserInfo.
- Apple and Google require PKCE. Apple retains its pinned-strategy nonce contract, including
  rejection of a missing nonce.
- Provider access, refresh, and ID tokens are not persisted. The Apple credential table, revocation
  queue, and legacy provider identity storage are removed by an irreversible migration.
- All three providers use `ExternalAuthentication::VerifiedPrincipal`; Entra adds a required typed
  tenant context. Entra lookup remains `(tid, oid)` while `(iss, sub)` is protocol evidence.
- Entra is fixed to a configured tenant, requires the optional `acct = 0` ID-token claim, and uses a
  certificate-backed PS256 client assertion. The database stores only the Rails credential key name.
- Social ceremony digests use `SOCIAL_AUTH_CEREMONY_HMAC_KEY`, not the Rails application secret.

## Review notes

- Ruby syntax was checked for all Ruby files and `git diff --check` passed.
- Rails tests could not start because the configured PostgreSQL host `primary` did not resolve.
- Rails boot verification was also blocked by the environment debugger attempting a disallowed Unix
  socket.
- Provider console configuration and controlled manual E2E remain release gates.
