# Visa OpenID Provider Host and Base Browser RP Boundary

## Status

Accepted and implemented in Rails (2026-10-24). This decision records the WU-02 host split and
supersedes the same-FQDN authority portion of `adr/base-authority-and-self-rp-separation.md`. The
role separation in `adr/op-auth-rp-authentication-responsibility-separation.md` remains applicable.

## Context

Base originally served both the OpenID Provider and its own browser relying party on the same host
family. That made a host-local cookie or controller ancestry an unsafe signal of which role a
request was using. It also made issuer, Jump return, logout, ceremony-binding and UI ownership
contracts depend on one value named as a Base authority host.

## Decision

Visa is the only Rails OpenID Provider and authority surface for the three UMAXICA realms:

| Realm | Visa OP            | Base RP           | Auth ceremony      | Logical host identities      |
| ----- | ------------------ | ----------------- | ------------------ | ---------------------------- |
| app   | `visa.umaxica.app` | `www.umaxica.app` | `auth.umaxica.app` | `visa-app-ww`, `base-app-ww` |
| com   | `visa.umaxica.com` | `www.umaxica.com` | `auth.umaxica.com` | `visa-com-ww`, `base-com-ww` |
| org   | `visa.umaxica.org` | `www.umaxica.org` | `auth.umaxica.org` | `visa-org-ww`, `base-org-ww` |

Visa owns discovery, JWKS, authorization, token, UserInfo, revocation, end-session logout, authority
sign-out result, session-limit resolution and sign-in-path ceremony binding. Base owns the browser
RP callback, RP credentials and cookies, dashboard and identity pages, re-verification, and
RP-initiated logout. Auth owns credential ceremonies and provider callbacks; provider callback
registrations do not move to Visa.

The public and development host contracts are explicit. Visa uses
`VISA_{SERVICE,CORPORATE,STAFF}_URL` or its public deployment equivalents
`PUBLIC_VISA_{SERVICE,CORPORATE,STAFF}_URL`, with `visa.{app,com,org}.localhost` as local hosts.
Base keeps its existing `BASE_*` / `PUBLIC_BASE_*` RP contract. Missing required production
configuration fails closed; no host wildcard or Base-to-Visa fallback is permitted.

Visa OIDC and authority credentials use independent `VISA_APP`, `VISA_COM` and `VISA_ORG` JWT
namespaces and key sets. Base retains `BASE_APP`, `BASE_COM` and `BASE_ORG` for Base-owned Jump and
RP responsibilities. A Visa issuer never signs a token under a Base namespace, and the application
accepts no old `www` issuer as a compatibility path. The `visa-*` and `base-*` names above are
logical host identities, not OIDC client IDs; Base RP client registrations remain the existing
`base-*` identities.

Ceremony contract JWTs follow the path that owns the decision: the live App social sign-up grant is
issued and verified with `VISA_APP`; Step-Up/re-verification grants continue to use the matching
`BASE_*` namespace. The grant contract selects the expected issuer from the explicit namespace; it
never infers a Visa/Base role from the request host.

Visa and Base use host-only cookies and Rails sessions. Visa cannot clear Base cookies, and Base
cannot use its RP credential as Visa authority proof. Cross-host navigation uses the Rails-side Jump
edge catalog in `docs/operations/jump-rt-visa-edges.md`; the separate Edge/Jump service and its
deployment configuration are outside this repository change.

## Consequences

The route, controller, issuer, CSP, Host Authorization, FQDN, key namespace and UI inventories must
name Visa explicitly. Base route helpers and URLs now describe RP destinations, while Visa route
helpers describe authority destinations. Logout is authority-first: Base launches to Visa, Visa
commits authority cleanup, and the browser returns to Base for local RP cleanup. A deployment must
update the external Jump graph and provision the three Visa production key sets before a cross-host
browser flow can operate outside Rails tests.

The old Base OP paths are removed rather than redirected or aliased. This is intentional because the
application is not deployed and accepting both issuer families would create an ambiguous trust
boundary.

## Verification

The implementation is covered by the host exclusivity, Base route withdrawal, issuer/JWKS,
ceremony-binding purpose, Jump edge catalog, OIDC browser, logout and static invariant tests. The
Rails-side Jump handoff is documented but external Edge integration is not claimed.
