# Preference, Setting, and Configurator URL Boundaries

**Status:** Accepted (2026-06-02)

> **Supersession (2026-06-02):** This ADR's IdP/RP-centered authority model is superseded by
> `adr/identity-authority-boundary.md`. `acme/www` is now the Session, Token, Account, Preference,
> and Authorization Authority. `sign/id` is no longer the IdP; it is a Credential Gateway and
> Credential Ceremony Zone only. Historical implementation details in this ADR must not be used to
> reintroduce sign-side sessions, refresh tokens, preference writes, dashboards, account lifecycle,
> downstream token issuance, authorization decisions, or step-up freshness.

## Context

The sign hosts expose several user-facing flows that can look similar because they all change
personal or operational state. The URL boundary needs to make the actor and authentication contract
clear before implementation details, controller names, or legacy route names are considered.

The current code still contains plural `/settings` routes in some places. Those routes are an
implementation compatibility gap, not the target URL language for new documentation or route work.

## Decision

Use these canonical URL roles:

- `/preference` is the login-independent preference boundary.
- `/setting` is the signed-in user setting boundary.
- `/configurator` is the operator-controlled configuration boundary.

`/preference` may be used by anonymous and authenticated actors. It owns preferences that are not
inherently tied to a signed-in account, such as language, region, timezone, theme, display options,
and cookie consent. When an authenticated actor uses this flow, the preference subsystem may sync
shared surface preference and actor-local preference records according to the accepted preference
doctrine, but the route remains a preference route rather than an account settings route.

`/setting` requires a signed-in actor on the current surface. It owns the actor's own account and
security settings, such as credentials, sessions, MFA, contact methods, notification settings, and
withdrawal flows. These routes must use the surface-local authentication, authorization,
verification, CSRF, rate-limit, and step-up pipeline.

`/configurator` requires an operator or another explicitly authorized operational actor. It owns
configuration that an operator controls for an organization, workspace, tenant, public surface, or
managed runtime. It is not a shortcut for user self-service settings and must not bypass the
operator authorization pipeline.

The three boundaries are surface-local. `app`, `org`, and `com` controllers, routes, policies,
sessions, and state remain independent unless an existing shared abstraction explicitly permits the
shared behavior.

## Consequences

- New documentation should use `/preference`, `/setting`, and `/configurator` for these roles.
- New route work should avoid introducing new plural `/settings` paths. Existing plural routes need
  a separate migration or compatibility plan before they are renamed.
- Preference writes stay in the preference subsystem. They must not be moved under `/setting` merely
  because an authenticated actor is present.
- User self-service account settings stay under `/setting`. They must not be exposed through
  `/preference` just because the screen also displays locale or theme.
- Operator-managed configuration stays under `/configurator`. It must not be mixed with user
  self-service setting routes or anonymous preference routes.

## Owner-approved migration: Base ORG settings (2026-10-31, WU-X1)

The owner approved a one-route exception to the generic `/configurator` path for the existing Base
ORG management entry: it moves from `/configuration` to `/settings` on the Base ORG host. This route
is distinct from Auth APP and ORG `/settings`, which remain surface-local identity settings on their
Auth hosts. Matching path text does not share controllers, sessions, authorization, or state across
those hosts.

The Auth ORG `/configuration` transfer endpoint is removed. No `/configuration` alias or redirect is
retained. The Base ORG endpoint remains closed until it has an authoritative settings data source.
This migration is specific to Base ORG; `/configurator` remains the generic path for new
operator-managed configuration routes.

## Owner-approved Auth identity migration (2026-11-04, Step-Up revision 13 O-11)

The accepted O-11 surface contract supersedes the earlier statement that Auth APP and ORG
`/settings` remain identity self-service endpoints. Auth ORG `/settings` and `/settings/entra` are
retired without aliases. Entra sign-in remains an Auth ceremony using administrator-provisioned
identities; Base ORG `/identity/social_identities` owns only the read-only Entra status display. APP
TOTP management and APP social status/unlink move to Base APP identity. Auth APP social link starts
require the Visa-mediated O-9 admission, whose implementation remains disconnected pending review.
This migration does not create a self-service ORG Entra link or unlink path.

## Related

- `adr/preference-soft-bubble-doctrine.md`
- `adr/sign-prefix-routing.md`
- `adr/two-base-authentication-mode-boundaries.md`
- `docs/architecture/preference.md`
- `docs/architecture/controller-boundaries.md`
