# Base, app Secret, and Core contract precedence

## Status and scope

Accepted for the target contracts explicitly decided by the user. Recorded on
2026-10-03 (UTC). Acceptance records a design decision, not implementation,
verification, deployment, or permission to start another implementation task.

This ADR reconciles earlier decisions for Base app/com/org, app Secret, and Core.
Supersession is limited to the clauses below. Other surfaces and unrelated clauses
remain governed by their existing ADRs. Existing records are retained.

## Context

Earlier records describe anonymous Dashboard rejection, app Emergency credentials,
AAL-oriented Step-Up terminology, and Workers-mediated Core routing. Combining
those records without explicit precedence can restore retired behavior. The latest
user clarification also distinguishes passive Sign display from Sign initiation.

The [integration analysis](../plans/analysis/base-secret-core-integration.md)
describes dependencies. The [acceptance catalog](../plans/analysis/base-secret-core-acceptance.md)
defines the evidence needed to judge delivery. Neither is a parallel active backlog.

## Decisions

### Base and session authority

For Base app/com/org, anonymous HTML Dashboard navigation uses the existing gate
to the same Base's `/sign`. Only the Dashboard action becomes private; public Home,
authenticated Home rejection, authorization, and selector contracts remain intact.
JSON/API, Inertia, and HEAD retain their respective response contracts. HEAD does
not start authentication.

GET `/sign` is passive display, including for an authenticated visitor. Display
alone is not a terminal-rejection violation. POST `/sign` starts a new ceremony
only through explicit user action; an authenticated caller's new start is rejected
without automatic logout, compensating redirect, or session replacement. Continuing
the same valid transaction is distinct from starting another one.

Use existing local admission, signed Jump, result delivery, and validated return
mechanisms. Auth supplies ceremony evidence; Base owns browser-session establishment
and OAuth/OIDC authority. Base is not its own RP. Auth does not directly establish
a Base session. The canonical `log_in(resource, establishment:)` boundary, or its
verified successor, retains flow checks, limits, cooldown, and post-commit effects.

### app Secret and database boundaries

Secret is app-only, server-generated `SecureRandom.base58(32)`, case-sensitive,
and accepted once for normal Sign in. It is neither Step-Up evidence nor recovery
evidence. A normal Secret-derived session may satisfy a later Step-Up using another
method allowed by the existing operation requirement.

Rebuild `ClientSecretCredential` without inheriting old app Secret data, kinds,
statuses, variable-use counters, compatibility paths, or Emergency semantics.
The former five-minute lifetime, five-attempt policy, and temporary-access context
do not apply. Preserve com Recovery Secret and org Emergency behavior.

Derive lifecycle state from immutable references and fact timestamps, using existing
`discard_at` and `purge_eligible_at` retention vocabulary. Ownership is
`client_id -> clients.id`. Pending candidates are not usable credentials.

Zenith owns Client and credential facts and the reservation needed to enforce
`A <= 20` and `A + R <= 20` atomically. Ticket is authoritative PostgreSQL for its
flow, token, and transaction state; it is not a cache. Place data by the invariant
and transaction that must own it, rather than by lifetime alone. Do not merge these
databases or replace Ticket state with Valkey. No cross-database atomic transaction
is assumed.

At Passkey-registration issuance reservation, writer-database count A determines
two candidates for A=0..18, one for A=19 with a limit-reason notice, and none for
A=20 with a normal omission notice. At 20, create no random value, candidate,
plaintext payload, or capacity reservation. Preserve the omission result for that
registration's retries. Two is a distribution count, not a minimum holding count.
Manual addition issues one. Consumption to one or zero does not trigger replenishment
or restrictions. Reservations R are not valid credentials or account-state counts.

All capacity-changing operations share database ownership and lock order. A pending
issuance binds the exact candidate set to its Client, operation, and browser or
sign-up flow. Presentation is explicit and protected; confirmation is a user's
storage declaration, not authentication or Step-Up proof. Missing payload does not
cause an unpresented replacement value to be confirmed.

After complete verification, atomic Zenith claim is irreversible acceptance.
Ticket failure never unclaims the Secret. Same-operation reconciliation from durable
flow/session receipts is distinct from accepting the input again. Session establishment
and credential acceptance are separate facts, and at most one root login may result.

Credential mutations and their source outbox commit in the same Zenith transaction;
Ticket mutations use a Ticket source outbox when required. Chronicle receives
idempotently delivered facts, not credentials. Physical deletion follows delivery of
preceding terminal audit facts; deletion and the purge-event outbox commit together.
The outbox survives deletion and the purge event is delivered afterwards.

### Step-Up and Core

Use existing operation requirements with allowed methods, scope, freshness, actor,
session, transaction binding, and applicable one-time consumption. Do not replace
authorization with a numeric AAL threshold. Newly registering a Passkey is not
self-authorization. Signed-in Secret operations have no bootstrap exemption; initial
sign-up uses its separate verified enrollment authorization.

Core's browser calls Rails-owned paths on the configured public Core origin.
Workers/TanStack do not proxy user requests to Rails, store authentication credentials,
or perform refresh. Common SSR remains possible; user-specific Rails access starts
in the browser with an initially unconfirmed authentication state.

Strip Cookie before ordinary TanStack application handling and strip UI-generated
Set-Cookie; preserve Rails-owned authentication responses. This is an application
boundary, not a claim that credentials never reach Cloudflare infrastructure.
User-specific dynamic responses have no shared cache; fingerprinted static assets
may be cached. Preserve exact Origin pairs, CSRF, Fetch Metadata, limited protocol
exceptions, final Rails authorization, and independent Rails/Cloudflare rate limits.

Refresh changes are limited to repairing a demonstrably approved existing contract.
New endpoints, GET credential mutation, retry or rotation protocols, old-token grace,
response-loss recovery, and credential storage require a separate decision. A route's
existence is not approval. No transparent GET refresh is restored.

## Scoped replacement and preservation

| Existing record | Relationship to this decision |
| --- | --- |
| [Home/Dashboard boundary](home-dashboard-authentication-boundary.md) | Replace anonymous Base Dashboard's 404/no-guidance clause. Preserve Warp, Home, authenticated boundaries, and Core presentation ownership. |
| [Neutral Sign and logout authorization](sign-neutral-entry-and-logout-target-authorization.md) | Clarify that authenticated passive GET display is allowed; authenticated new POST starts are refused. Preserve logout authorization and Jump contracts. |
| [Emergency Secret commit acknowledgement](emergency-secret-credential-commit-acknowledgement.md) | Replace app Emergency purpose and entry behavior with normal single-use app Secret. Preserve the safety requirement for durable irreversible claim and session-commit evidence; do not reuse legacy issuance semantics. |
| [Step-Up redesign](step-up-authentication-redesign.md) | Use current operation requirements and prohibit signed-in app Secret bootstrap. Preserve unrelated methods and policies; this is not a global bootstrap-policy rewrite. |
| [Principal/Zenith consolidation](principal-zenith-physical-consolidation.md) and [database ownership](global-regional-database-ownership.md) | Preserve current ownership. Clarify that short-lived reservation may belong to Zenith and Ticket remains authoritative PostgreSQL. |
| [Base/Auth and RP boundary](base-auth-ceremony-and-seven-rp-boundary.md) | Preserve authority separation. Historical callback names and authenticated-root presentation are not current routing instructions. |
| [Root-login establishment](root-login-establishment-boundary.md) | Preserve the canonical issuance boundary and local transaction/commit requirements. Secret is an additional evidence source, not another issuer. |
| [Core transport/UI boundary](core-browser-jwt-cookie-transport-and-nextjs-zero-cookie-boundary.md), [canonical Core host](core-canonical-public-host.md), and [TanStack UI boundary](tanstack-start-zero-cookie-ui-origin-boundary.md) | Preserve current amendments defining browser-owned Rails access and zero-cookie UI. Earlier Workers/VPC proxy and token-transport descriptions are historical, not fallback contracts. |
| [Retention columns](retention-lifecycle-column-boundary.md) and [retention purge](retainable-concern-and-retention-purge.md) | Preserve retention vocabulary and applicable controls. For app Secret, replace unaudited generic deletion with one audit-aware deletion owner or delegation. Preserve com/org behavior. |
| [Chronicle consolidation](chronicle-audit-db-consolidation.md) and [audit guidance](chronicle-audit-implementation-guidance.md) | Preserve Chronicle ownership and audit boundaries. Add source-database outbox guarantees; do not claim a distributed transaction. |
| [Jump handoff](jump-directed-rails-handoff-contract.md) | Preserve signing, purpose, destination, TTL, replay restrictions, and the configured gateway. No graph or query-preservation expansion. |

### A conflict that this ADR does not silently resolve

[Invalid browser credential recovery](invalid-browser-credential-recovery.md)
includes Core RP credential-pair cleanup. Access expiry with valid continuation
credentials must be distinguished from confirmed invalidity. Whether the current
resolver can make that distinction through an approved continuation route requires
runtime evidence. Do not blanket-disable cleanup or invent refresh to reconcile it.
Block only the dependent continuation change until this contract is established.

## Alternatives and consequences

Blanket supersession would erase valid Warp, com/org, logout, and protocol decisions.
Keeping all older clauses simultaneously would restore contradictory behavior.
Scoped replacement makes the target explicit while preserving historical reasoning.

Implementation must update old ADR backlinks and indexes when their concurrently
edited content is reconciled. This documentation task creates an independent record
instead of overwriting those files. Runtime support, unknown expiry settings, return
capability, and external routing remain separate verification or decision gates.

Secret maps to the Look-Up Secrets category in
[NIST SP 800-63B-4 section 3.1.2](https://pages.nist.gov/800-63-4/sp800-63b/authenticators/).
The source requires single successful use and protected storage; online delivery also
has AAL2-or-higher conditions. Category correspondence and an internal Step-Up
requirement do not establish full compliance. Delivery, binding, cryptographic, and
enrollment differences require explicit evidence, without introducing numeric AAL
authorization into the application.
