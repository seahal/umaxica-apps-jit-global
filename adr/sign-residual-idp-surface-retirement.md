# Sign Residual IdP Surface Retirement

> **Supersession (2026-09-13):** Auth is a ceremony service with no RP role. See
> `adr/base-auth-ceremony-and-seven-rp-boundary.md`.

## Status

Accepted; partially superseded (2026-09-13) (2026-06-11)

> **Supersession (2026-06-12):** The target component model is now defined by
> `adr/acme-sign-core-base-port-boundary.md`. Sign is a special RP, not a credential-gateway IdP
> host, and Acme is the only IdP / Authorization Server. This ADR remains useful for identifying
> residual sign-side IdP behavior to retire, but its retained `sign/id` credential-gateway framing
> is superseded where it conflicts with Sign as a special RP.

## Context

`adr/identity-authority-boundary.md`, `adr/acme-session-and-token-authority.md`, and
`adr/sign-credential-gateway-surface.md` already decide that `acme/www` is the identity authority
(Session, Token, Account, Preference, Authorization) and that `sign/id` is a Credential Gateway, not
an IdP.

The current code is still ahead-of-decision in the opposite direction: `sign/id` retains a parallel
OIDC provider, its own JWT signing key namespace, a refresh-token rotation endpoint,
session-mutating sign-out paths, and a step-up flow that writes session freshness. Two IdP-like
centers make the authentication and authorization boundary ambiguous and create real failure modes
when `acme` and `sign` both issue or mutate identity state.

This ADR is the operational decision record for retiring those residual surfaces. It records what is
removed from `sign/id`, and — importantly — the one credential ceremony that must stay on `sign/id`
for a non-authority reason (WebAuthn URL binding). It does not change the higher-level authority
boundary; it operationalizes it.

The `id.example.com` host boundary (`SIGN_*_URL` = `id.umaxica.app` / `.com` / `.org`) is kept. Only
the responsibilities served under that boundary change.

## Decision — Retire from `sign/id` (consolidate into `acme/www`)

The following are removed from `sign/id`; `acme/www` is the sole authority. Code removal is tracked
as follow-up implementation, not performed by this ADR.

1. The `sign/id` OIDC **provider** endpoints across all surfaces (app/com/org): `/oauth/authorize`,
   `/oauth/token`, `/oauth/userinfo`, `/oauth/revoke`, `/.well-known/openid-configuration`, and
   `oidc/logout`. These advertise and operate `sign/id` as an OIDC issuer; the IdP is `acme/www`
   only. `OidcIssuer` already resolves only `acme` hosts and issuers, so these sign endpoints mint
   acme-issuer tokens and are vestigial.

   **Explicitly retained — not an IdP surface:** the `sign/id` `/.well-known/jwks.json` endpoint and
   the `surface:SIGN_APP` / `surface:SIGN_COM` / `surface:SIGN_ORG` signing keys
   (`lib/jit_security_jwt_registry.rb`). These are issued with `issuer = https://id.umaxica.*` and
   `audience = JUMP_GATEWAY_URL`; they sign **jump redirect-gateway (RT) tokens** and surface
   redirect/transport tokens, and the sign JWKS endpoint publishes their public keys for
   verification. They are credential-gateway / redirect-signing infrastructure, **not** OIDC
   id-token signing. OIDC id tokens are signed with `surface:ACME_*`. OIDC client-auth keys such as
   `oidc_client:SIGN_*`, `oidc_client:ACME_*`, and `oidc_client:CORE_*` are RP client assertion keys
   and do not make `sign/id` an OP. Removing the retained `surface:SIGN_*` keys would break jump
   redirects and token verification from `sign/id`.

2. (Removed.) An earlier draft of this ADR proposed retiring the `SIGN_APP` / `SIGN_COM` /
   `SIGN_ORG` signing key namespaces. That was based on a wrong premise: those keys are the
   `sign/id` surface jump-RT / redirect signing keys, not IdP id-token keys, and are retained. See
   item 1.
3. The `sign/id` refresh-token rotation surface: the surface refresh endpoints under
   `sign/.../edge/v0/token` and the no-behavior compatibility subclass `SignRefreshTokenService`.
   Refresh rotation is owned by `AcmeRefreshTokenService`, which the shared refresh entrypoint
   already calls directly.
4. The `sign/id` session-mutating sign-out paths: the multi-step sign-out flow action that calls
   `logout_current_session!`, and the `SignOidcLogout` concern that calls `log_out`. Session
   mutation is owned by `acme/www` (`acme/.../sign_outs` and `acme/.../oidc/logouts`). A
   redirect-only `sign/.../sign_outs` shell that forwards to `acme/www` may remain.
5. The `sign/id` step-up freshness writes and self-issued grants: the success path that writes
   `last_step_up_at`, `last_step_up_aal`, `last_step_up_scope`, and `last_step_up_method` onto the
   token, and the compatibility paths where `sign/id` issues its own step-up ceremony grant when no
   `acme/www` grant is present. Step-up freshness is committed only by `acme/www`
   (`IdentityStepUpCeremonyFreshnessCommitter`, via the acme completion path). `sign/id` must
   require an `acme/www`-issued grant and return only a signed result.

## Decision — Keep on `sign/id` (explicit exception)

Step-up credential ceremony execution (TOTP, passkey/WebAuthn) stays on `sign/id` at
`id.example.com` and its URL must not change.

The reason is not authority: it is that the WebAuthn RP ID and origin are bound to the URL. Changing
the URL would invalidate already-registered passkeys and make existing TOTP/passkey credentials
unusable. This is an explicit, narrowly-scoped exception.

What stays on `sign/id`: challenge and verification, short-lived ceremony state
(`*_step_up_session`), and signed ceremony result issuance (`IdentityStepUpCeremonyResultIssuer`).
This is consistent with the "credential ceremony execution" allowance in
`adr/sign-credential-gateway-surface.md`.

What does not stay (see Retire item 5): ownership of step-up freshness state, and self-issuance of
ceremony grants. `sign/id` consumes an `acme/www` grant and returns a signed result only.

## Consequences and Guardrails

- `sign/id` is not an IdP, a session authority, or a refresh-token authority. Future work must not
  reintroduce these to `sign/id`.
- The WebAuthn URL-binding exception is limited to step-up ceremony execution. It must not be
  stretched to justify step-up freshness storage, grant self-issuance, session mutation, or token
  issuance on `sign/id`.
- Downstream services (`core`, `line`, and future services) trust only `acme`-issued tokens for
  application authorization, as already decided in `adr/identity-authority-boundary.md`.

## Implementation Boundary

This ADR does not change code. The retirements in items 1–5 are implemented in follow-up work, with
these constraints:

- The refresh consolidation depends on the session/refresh cookie being readable and writable by
  `acme` (apex-domain scope) with CORS/CSP permitting it; confirm or adjust cookie domain first.
- Step-up ceremony routes and URLs on `sign/id` are not changed (passkey compatibility).

## Related

- `adr/identity-authority-boundary.md`
- `adr/acme-session-and-token-authority.md`
- `adr/sign-credential-gateway-surface.md`
- `adr/sign-prefix-routing.md`
- `adr/device-session-dbsc-device-id-boundary.md`
