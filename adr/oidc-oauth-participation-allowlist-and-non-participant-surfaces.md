# OIDC/OAuth Participation Allowlist and Non-Participant Surfaces

## Status

Accepted (2026-10-05)

Extends, and does not supersede, `adr/base-auth-ceremony-and-seven-rp-boundary.md`. That decision
established Base as the physical IdP / Authorization Server, Auth as ceremony-only, and the
first-party RP boundary. This decision defines the inverse boundary: the surfaces that do not
participate as an UMAXICA OAuth/OIDC RP, IdP, or Authorization Server.

## Context

UMAXICA does not infer OAuth/OIDC participation from a hostname, TLD, Rails namespace, shared
database, shared process, or access-control middleware. Without a written rule, a surface can
acquire authentication participation by accident: a shared concern is included for convenience, a
parent controller gains a callback, or a new regional host is assumed to behave like the product
host it resembles.

This boundary is separate from ordinary access control. A Non-Participant may still be protected by
Cloudflare Access, HTTP Basic authentication, network ACLs, signed routing tokens, or another
purpose-specific control. Those mechanisms do not make the surface an UMAXICA OAuth/OIDC
participant.

The repository already largely follows this boundary. The current implemented state is described in
`docs/architecture/oidc-non-participant-surfaces.md`.

## Decision

### 1. Authentication participation is allowlisted

A surface is an UMAXICA OAuth/OIDC participant only when the authentication architecture explicitly
assigns it one of these roles:

- Base IdP / Authorization Server authority;
- an approved first-party RP client and RP face;
- an approved native RP client.

Everything else is an OIDC/OAuth Non-Participant unless a later accepted ADR reclassifies it.

`AuthBoundaryAuthorityMap`, together with the registries and contracts derived from it, is the
intended single source of truth for this allowlist. Hostname shape, TLD, route namespace, or
similarity to an existing participant is never sufficient to infer participation.

At the time of this decision the map enumerates the browser RP clients only. The approved native
clients are registered in the static client store but are not yet listed in the map. Closing that
gap is implementation work recorded in `plans/backlog/oidc-non-participant-contract-tests.md`; it
does not change this decision.

The hostname lists below are examples and current inventory. They are not the classification
mechanism.

### 2. All `.dev` surfaces are Non-Participants

Every current and future UMAXICA `.dev` surface is outside the UMAXICA IdP/RP system, regardless of
whether it is operated by Base, Core, a diagnostic tool, or another component. A developer surface
does not become an RP because the corresponding `.app`, `.com`, or `.org` product surface is one.

Current examples:

- `www.umaxica.dev`, the Base developer surface;
- regional Core developer surfaces, currently `jp.umaxica.dev`, expected to gain further
  region-qualified hosts;
- `mission`, `flipper`, `blazer`, `pghero`, `performance`, `coverband`, `swagger`, and `status`
  under `umaxica.dev`.

The regional hostname inventory may change. The invariant does not.

### 3. All `.net` surfaces are Non-Participants

Every current and future UMAXICA `.net` surface is outside the UMAXICA IdP/RP system, including
private and network-only `.net`-class services and aliases.

Current examples: `guid.umaxica.net`, `asset.umaxica.net`, `jump.umaxica.net`.

Jump may process signed routing material and may expose or consume JWKS-related material. That does
not make Jump an OAuth client, OIDC RP, IdP, Authorization Server, Base Browser Session authority,
RP Session authority, or Refresh Token authority.

### 4. Public-content faces under `.app`, `.com`, and `.org` are Non-Participants

The Info, Docs, News, and Help product faces are Non-Participants on all three product TLDs. At the
time of this decision that is twelve faces:

| Family | `.app` example        | `.com` example        | `.org` example        |
| ------ | --------------------- | --------------------- | --------------------- |
| Info   | `info.umaxica.app`    | `info.umaxica.com`    | `info.umaxica.org`    |
| Docs   | `docs.jp.umaxica.app` | `docs.jp.umaxica.com` | `docs.jp.umaxica.org` |
| News   | `news.jp.umaxica.app` | `news.jp.umaxica.com` | `news.jp.umaxica.org` |
| Help   | `help.jp.umaxica.app` | `help.jp.umaxica.com` | `help.jp.umaxica.org` |

Twelve is an inventory statement, not an architectural constant. Adding another region or hostname
variant does not create an RP.

### 5. Auth and Xper are identity-adjacent Non-Participants

Auth is ceremony-only. It is not an OAuth/OIDC RP and is not the IdP / Authorization Server. It
keeps the ceremony-local state and one-time opaque handoff and result capabilities defined by
`adr/base-auth-ceremony-and-seven-rp-boundary.md`.

Xper currently issues no credentials (`adr/xper-phase-zero-bootstrap.md`). The intended direction is
the same broad boundary as Auth: Xper may later use short-lived, purpose-bound, one-time transport
capabilities where Experience workflows require them, but it must not become an OAuth/OIDC RP, IdP,
Authorization Server, Base Browser Session authority, RP Session authority, or Refresh Token
authority for that purpose.

Until a later accepted ADR changes these roles, both are Non-Participants.

## Non-Participant Contract

An OIDC/OAuth Non-Participant surface MUST NOT:

- be registered as an UMAXICA OAuth/OIDC client;
- create, own, or authenticate through an UMAXICA RP Session;
- use a Base Browser Session as local login proof;
- issue, read, refresh, or revoke UMAXICA RP Access Tokens or Refresh Tokens;
- issue or consume `__Host-oidc_rp_access` or `__Host-oidc_rp_refresh` as a local authentication
  mechanism;
- treat an Auth ceremony credential (`__Host-auth_*`) as local authentication proof;
- expose `/sign` as an UMAXICA RP entrypoint;
- expose `/oidc/callback` as an UMAXICA RP callback;
- expose Base authority endpoints such as `/oauth/authorize`, `/oauth/token`, `/oauth/userinfo`, or
  `/oauth/revoke`;
- call UserInfo in order to establish a local UMAXICA RP login session;
- include shared UMAXICA RP/IdP authentication concerns for convenience, inheritance reuse, or
  future use;
- silently fall back to another surface's cookies, session state, client registration, token
  authority, or actor authentication state.

Auth is the one Non-Participant that owns state named in this list. It owns `__Host-auth_sid` as
ceremony-local state and a `/sign` ceremony namespace. Neither is login proof and neither is an RP
entrypoint, on Auth or anywhere else. The contract forbids every surface, Auth included, from
treating them as such.

A Non-Participant may use a separate access-control mechanism appropriate to its purpose. That does
not change its classification.

## User-Specific Content State

`adr/docs-help-news-discussion-moderation-notification.md` is Proposed and describes future
per-user values such as `watch_state`, `tracking_state`, and `muted_state` for Docs, Help, and News.
This decision constrains any implementation of that proposal:

- Docs, Help, and News remain Non-Participants by default.
- Public, read-oriented content endpoints may continue to live on those content surfaces.
- Discussion, notification, moderation, watch, mute, tracking, or policy state that requires an
  authenticated UMAXICA actor MUST be served through an authenticated RP-owned boundary, such as
  Core or another explicitly approved RP or API authority.
- A content surface MUST NOT gain RP cookies, RP Sessions, OIDC callbacks, or UserInfo login
  establishment in order to expose per-user discussion state.

This decision does not otherwise supersede that proposal.

## Reclassification Rule

Moving a Non-Participant into the UMAXICA OAuth/OIDC system requires a new accepted ADR and explicit
admission to the participation allowlist. At minimum the ADR defines:

- protocol role;
- client identity and exact client ID where applicable;
- issuer and audience bindings;
- exact redirect URI and logout endpoints;
- RP Session ownership;
- Access and Refresh Token transport;
- cookie boundaries;
- refresh behavior;
- UserInfo behavior;
- sign-out semantics;
- removal of the previous Non-Participant assumptions;
- regression tests proving surface isolation.

No compatibility fallback or inheritance rule promotes a Non-Participant into an RP.

## Verification

Policy scope and repository scope differ. Some surfaces named here, such as Jump, the asset host,
and the status host, have no route set in this repository. They are governed by this decision and
verified by the repository or deployment that owns them. A local route is not invented in order to
test them.

For repository-owned surfaces, this decision requires structural regression guards over the public
route, controller, and registry relationships, failing closed when a participant is not explicitly
allowlisted. Those guards are not yet written; the required set is recorded in
`plans/backlog/oidc-non-participant-contract-tests.md`.

## Implementation Progress

### 2026-10-05 Actor lifecycle removed from the Base developer and network faces

`Base::Dev::ApplicationController` and `Base::Net::ApplicationController` no longer include
`Session`, `ActorSupport`, or `Finisher`, and no longer declare `set_current_context`,
`reset_flash`, `with_actor_lifecycle`, or the `current_actor` helper. Their rate limit, browser
gate, CSRF strategy, no-store default, FQDN gate, and `AUTHENTICATION_MODE = :deny_all` are
unchanged.

The reasons for removing rather than keeping them:

- `ActorSupport` is the concern that authenticating surfaces use to install an actor. On a
  Non-Participant it is exactly the shared authentication concern the contract above forbids
  keeping for convenience or future use. These two were the only Non-Participant stacks that
  included it.
- It did no work there. Each controller is inherited only by its `RootsController`. Neither defines
  a credential source, so the concern could only install an anonymous context, and neither root
  page reads that context: the developer page is a standalone document that takes its theme from
  the `ct` cookie, and the network page renders plain text.
- Nothing else in the two stacks depends on it. `FqdnAvailabilityGate`, `RateLimit`, and
  `DefaultNoStore` do not read `Actor`, and `Actor` returns an empty context without raising when
  none is installed.
- `Session` and `Finisher` were inert on these controllers: `reset_flash` and `finish_request` are
  no-ops.
- The Xper application controllers already serve landing pages with the same reduced stack.

`test/controllers/concerns/application_controller_common_patterns_test.rb` required every surface
application controller to include these concerns. It now excludes `base/dev` and `base/net`, as it
already excluded Xper. No test case was deleted, so the authenticating surfaces keep their checks.

This change was made without running the test suite, as a one-time exception approved by the
repository owner. See `evidence/2026-10-05-base-dev-net-actor-lifecycle-removal-Q7N3.md`.

## Rationale

Host-bound credentials and explicit RP Sessions give useful isolation. Extending them to public
content, diagnostic, utility, network, or developer surfaces enlarges the authentication attack
surface without a corresponding requirement.

Becoming an RP creates durable protocol obligations: client registration, callback validation, token
exchange, UserInfo processing, refresh behavior, session ownership, logout semantics, and security
regression testing. Those obligations must not appear through incidental Rails code reuse.

An allowlist scales better than hostname enumeration. Regions, hosts, and deployment topology can
change without changing the default: a new surface is a Non-Participant until it is admitted.

The boundary also lets content and operational systems evolve independently. A feature can require
authenticated user-specific data without forcing the public content host to become an RP, because
the authenticated portion stays behind an RP-owned API boundary.

## Consequences

- The participation allowlist is the normative boundary; hostname inventories are documentation.
- `.dev` and `.net` stay outside the UMAXICA IdP/RP mechanism unless a future ADR changes that.
- Info, Docs, News, and Help stay public-content Non-Participants as regional hostnames expand.
- User-specific discussion and notification state cannot pull Docs, Help, or News into the RP
  architecture.
- Authentication-concern leakage into a Non-Participant is an architectural and security
  regression, not an ordinary refactor.

## Related

- `adr/base-auth-ceremony-and-seven-rp-boundary.md` — Base, Auth, and RP authority boundary that
  this decision extends.
- `adr/docs-help-news-discussion-moderation-notification.md` — Proposed discussion design,
  constrained by the user-specific state section above.
- `adr/read-only-content-surfaces-in-rails.md` — current public content boundary.
- `adr/xper-phase-zero-bootstrap.md` — Xper Phase 0, which issues no credentials.
- `docs/architecture/oidc-non-participant-surfaces.md` — current implemented state and inventory.
- `plans/backlog/oidc-non-participant-contract-tests.md` — regression guards still to be written.
- `adr/defer-auth-xper-transient-workflow-redesign.md` — defers the Auth and Xper workflow redesign
  and keeps their public origins stable.
- `memos/2026-10-05-claude-auth-xper-transient-workflow-future-design.md` — non-authoritative
  discussion of a future Auth and Xper transient-workflow redesign; not a decision.
