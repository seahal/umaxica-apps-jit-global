# Authentication Rollout Contract

This document is the deployment handoff for the Base authority, the seven first-party browser RPs,
Auth ceremony admission, and the identity-binding migrations. It describes prerequisites and
rollback boundaries; it does not authorize a shared-database migration or a security downgrade.

## Public identifiers

Every surface must use its registered FQDN, RP ID and exact Origin. The Base authority uses the
canonical application hosts; self-RP and first-party clients use their own registered client IDs.
Warp is the delivered replacement for the old Side internal name. Issuer, audience, redirect URI,
JWKS key identifier and RP ID are allowlisted values, not values inferred from the request Host.

The deployment configuration must preserve host-only RP access and refresh cookies, the configured
CSP and Fetch Metadata policy, and the Core zero-cookie edge contract. A proxy must preserve the
headers required for Origin, CSRF and callback validation and must not forward credential cookies to
the zero-cookie Core UI edge.

## Key and callback prerequisites

Provide the production Rails key material, signing-key/JWKS trust configuration, OIDC issuer and
registered callback/logout URIs before enabling a surface. Verify UserInfo, discovery, token and
revocation endpoints against the exact client allowlist. Real provider callbacks, OTP delivery,
WebAuthn RP ID/origin, and notification delivery require separate pre-production verification.

## Migration sequence

Apply the migrations in repository order on an approved maintenance path. Preflight ambiguous
identity, binding, token, receipt and retention rows; abort with non-secret identifiers rather than
inventing state. Build reference data, backfill deterministically, create indexes, validate
constraints, then retire redundant columns. Preserve terminal/audit history and run both the empty
database and representative old-schema reconstruction checks.

The app Secret rebuild drops only the old Secret objects after the legacy rows have been captured by
the migration's explicit transition. The verified transition preserves the Client and unrelated
table counts, creates no replacement credential for the legacy row, and leaves the new schema with
the current ownership and replay barriers. Shared production databases were not changed by the
implementation work.

## In-flight operations and stop conditions

During rollout, pending sign-in, sign-up, sign-out, step-up, binding, OIDC callback, Secret
issuance, Secret delivery and logout operations must finish under their existing owner and expiry
rules. Do not revive an expired or cancelled operation. Stop before traffic enablement if any
reference table is ambiguous, a constraint cannot validate, a required key or Origin is missing,
an outbox authority snapshot is unknown, or an audit/retention dependency is unavailable.

## Stop and rollback

Stop traffic to the affected surface, preserve logs and immutable operation identifiers, and use
the forward repair/reconciliation path. Do not restore Auth login-session dependence, re-enable a
custom CSRF acceptance path, broaden a cookie domain, or drop a validated foreign key as a rollback
shortcut. A schema rollback requires an approved replacement lifecycle and a tested data-recovery
plan; it is not the inverse of constraint validation.

## Retention and operations

Run the per-model candidate, payload, reservation, flow, terminal-claim, receipt and Secret proof
collectors with legal/enforcement holds and kill switches enabled. Keep parent rows while a live
child, result receipt or replay barrier depends on them. Chronicle confirms audit delivery but does
not become the authority for identity or credential resolution. Monitor refusal codes, migration
errors, outbox delivery, refresh coalescing, callback failures and credential-failure versus
dependency-failure responses.

The deployment checklist is incomplete until real-provider verification, shared migration approval,
FQDN/RP ID/Origin review, key and JWKS review, notification verification and Chronicle retention
approval are recorded by the operators who own those systems.
