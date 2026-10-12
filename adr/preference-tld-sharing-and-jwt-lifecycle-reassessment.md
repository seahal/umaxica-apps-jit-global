# ADR: Preference Registrable-Domain Sharing and JWT Lifecycle Reassessment

**Status:** Proposed — Decision Deferred

**Date:** 2026-10-11

**Scope:** Preference only

**Review horizon:** Approximately three months; no automatic acceptance or scheduled implementation

## Context and evidence boundary

Preference holds user-selected display and usage settings. The database remains the durable source
of truth; a dedicated signed Preference JWT transports a projection, and Rails exposes the effective
request value through `Actor.preferences`.

The designer explained in the 2026-10-11 discussion that Preference grew out of technical experiments
with `auth_*` cookies. That explanation records design intent, not a motive established by Git.
History independently establishes earlier signed Preference cookies, the January 2026 introduction
of a seven-day access JWT with a 400-day refresh token, subsequent single-use rotation/replay
handling, and March DBSC additions. It also shows a temporary unified setting implementation that
was later removed. The [history and drift record](../evidence/2026-10-11-preference-architecture-history-and-drift.md)
contains revisions, inspected paths, classifications, and limitations.

These mechanisms now give low-sensitivity UX state a credential lifecycle resembling authentication.
Whether Preference still needs dedicated refresh and device binding is the question being reopened;
this does not reopen authentication's security contract.

Current Preference credentials are host-only. Base changes therefore do not directly supply the
canonical credential to sibling hosts. Registrable-domain-scoped display mirrors already cross hosts, but are not
the database source of truth. The desired sharing boundary is each **registrable domain**:
`umaxica.app`, `umaxica.com`, and `umaxica.org`, independently. “TLD sharing” in the filename is
historical shorthand: no cookie is to be scoped to the public suffix `.app`, `.com`, or `.org`.

## Requirements and invariants to preserve

The following are the designer's stated requirements for the eventual redesign, consistent with
the existing separation of Preference from security authority:

- The Preference DB MUST remain the source of truth. `app`, `com`, and `org` MUST remain independent
  Preference domains, with their corresponding shared and actor-local ownership boundaries.
- The design SHOULD make a Base change usable by Rails and frontend consumers within the matching
  registrable domain. Cross-domain identity or Preference sharing is outside this proposal.
- The Preference JWT MUST remain inaccessible to JavaScript. Its transport MUST use Secure and
  HttpOnly cookies. Display JSON/cookies MUST exclude JWTs and other credentials.
- Preference MUST remain display/usage state. It MUST provide no authentication, authorization,
  identity verification, age verification, AAL, user-presence, tenant selection, or permission proof.
- Rails MUST retain `Actor.preferences`. Server-side resolution and frontend presentation delivery
  MUST remain separate. A Rails resolver MUST be usable directly without Rails calling its own HTTP API.
- GET/HEAD MUST remain non-issuing: no JWT creation, replacement, refresh, or lifetime extension.
  Confirmed invalid-cookie detachment remains distinct from issuance; system failures remain errors.
- `auth_*`, RP, OIDC, browser/session issuance and security control order remain outside scope.
  Preference integration at login/sign-out must preserve these contracts.
- `continuity` remains a reserved, separate browser-state responsibility. This proposal implements
  neither it nor a substitute anonymous-recovery identifier.

## Direction under consideration

The discussion favors retiring Preference-only refresh and DBSC and centering the transport on one
JWT. Base would update the DB and alone sign/issue that JWT. Warp, Core, Auth and other approved Rails
consumers would validate with public keys and use a shared direct resolver. Domain-scoped HttpOnly
transport would distribute the projection within the matching registrable domain.

The intended retirement names are `feel_refresh` and `feel_dbsc`. The inspected local code still
writes `preference_access`, `preference_refresh`, and `preference_dbsc` (secure contexts add
`__Host-`). Existing ADRs mention `feel_*`, but that is not evidence that the rename has shipped.
The final access-cookie name and migration/deletion contract remain Open.

This direction is **Proposed**, not an approved topology. In particular, TTL, actual cookie scope
and attributes, audience/host validation, revocation, signing-key isolation and frontend delivery
remain undecided. Pure offline JWT verification would materially differ from current normal Rails
GETs, which also check the active, unconsumed DB row and its `jti`. Sharing a cookie alone does not
provide immediate propagation to open tabs, cached representations or retained token copies.

## Lifetime candidate and lifecycle questions

The current constants are seven days for access and 400 days for refresh. A 400-day JWT became a
leading candidate in this discussion because removing refresh would otherwise shorten anonymous
continuity to the current access lifetime. **400 days is not a decision or an approved risk acceptance.**
Cookie retention is also subject to browser deletion and storage policy; a nominal expiry is not a
promise that an anonymous user retains a recoverable identifier.

| Question | Current observation | Decision needed before implementation |
| --- | --- | --- |
| JWT `exp` versus cookie expiry | Codec computes integer `iat + 7 days`; issuer separately computes cookie expiry from a later clock read. | Use a defined issuance instant and absolute expiry; specify `Expires`/`Max-Age`, clock skew, inclusive boundary, and browser retention limits. A cookie cannot extend JWT validity. |
| DB `discard_at` versus JWT | `expires_at` aliases `discard_at`; bootstrap/rotation use 400 days, retirement sets it to now, and default infinity exists. Access issuance is not capped to the row's remaining life. | Define DB lifetime independently from transport validity, finite/infinite legacy treatment, and behavior when the row ends before the JWT. No automatic row-life extension is approved. |
| Base settings change | HTML and browser writes reissue access today; specialized APIs and adoption have different lifecycle paths. | Define explicit Base mutation/issuance transactions, generation and `jti` semantics, response failure, parallel-tab ordering, reset and safe sign-out copying. Determine how an already-open consumer learns of a change. |
| No non-Base issuance | Shared issuer/codec/key registry are reachable from multiple Rails families today. | Enforce writer capability and private-key provisioning at the process/deployment boundary, including login/sign-out integration, and prove consumers can boot with public keys only. A namespace convention alone is insufficient. |
| Anonymous expiry | Existing refresh can resolve a DB row without issuing on GET; there is no approved replacement recovery channel. | Decide what the visitor sees and loses after expiry/deletion and whether re-selection is acceptable. A retained DB row without a valid browser reference does not restore continuity. No hidden refresh, grace token or new `continuity` mechanism is proposed. |
| Revocation at offline readers | Signature/claims verification does not check current row retirement or current generation. | Decide permissible stale duration after update/reset/sign-out, whether all consumers have an online check, and how offline Edge behaves. Cookie deletion removes one browser copy, not a stolen JWT or another cached representation. |
| Old signing public keys | A helper expresses TTL plus one-hour JWKS and one-hour CDN allowances; no concrete Preference key-retention deployment was verified. | Retain verification keys from the last issuance under a key through the maximum accepted lifetime plus defined skew/distribution/cache allowances. For a 400-day candidate this is roughly 400 days plus margins, not the present seven-day assumption. Emergency compromise retirement is a separate decision. |
| Theft/reuse | HttpOnly prevents direct JS reads, not transmission to every matching server; DBSC currently binds refresh paths, not every access-JWT read. | Explicitly accept or reject long-lived display disclosure, replay, linkability, stale consent/display and possible Preference-write capability. Define reset/revocation remedies and consumer boundaries; no authentication or age authority may follow from possession. |

Removing DBSC removes binding protection where it currently applies. It would be misleading to
claim it currently protects every JWT presentation. Removing refresh also removes rotation/replay
machinery; it does not remove the need to define the row and projection lifecycles.

## Frontend delivery alternatives — no selection

| Alternative | Candidate use | Boundary questions and tradeoffs |
| --- | --- | --- |
| A. Rails BFF | An approved Rails family verifies the JWT, resolves Preference directly, and returns a small validated display JSON representation. | Define fields, staleness, error/cache behavior, request-local overlays and read-only consumers. Existing host-local theme/consent APIs write and issue tokens; they are not already the proposed read-only Base-issued design. |
| B. Preference-specific TanStack Start BFF | Consider a dedicated API entrypoint for Info/Docs/News/Help where no browser-facing Rails Preference BFF is exposed. | Define route ownership, credential admission and isolation from public content SSR/API clients; reconcile zero-cookie restrictions explicitly. This would change an existing boundary and requires approval, not generic cookie forwarding. |
| C. JS-readable display cookies | Consider existing short display projections such as `ct`, `tz`, `cu`, `df`, `tf`, `mo`, `dn`, and `ps`. | These are neither source of truth nor credentials. Define tamper validation, precedence, partial updates, generation skew, cache selection and safe recovery. Rails runtime authority remains separate. |

A/B/C and their combination are **Open**. JWTs remain HttpOnly under every alternative. Current
mirror cookies mean C is partly an existing implementation, but re-adopting it as a deliberate
frontend contract changes its scope, guarantees and precedence rather than introducing cookies
from nothing.

Core's [accepted TanStack boundary](tanstack-start-zero-cookie-ui-origin-boundary.md) excludes
Cookie/Set-Cookie and credential-based personalization from the UI origin. It explicitly approves
browser-to-Rails display reads after hydration. A BFF running on that UI origin would require an
explicit boundary decision. That Core-specific ADR is not automatically a universal rule for every
public host.

The inspected Edge `main` and `feature` differ: main retains the Astro transition record; feature
`1218ddca851933ab2f9498ad9f426acc69f78d6b` identifies the twelve public cells as TanStack and
preserves public Rails content-client credential stripping. Core strips Cookie before the app but
first derives a validated display-locale header from `language`, a potential conflict with the
Global no-credential-personalization wording. Deployment and newer local Edge work remain
Unverified. Reconcile this evidence before selecting B.

The designer reports a separately requested removal of Edge's `language` cookie dependency. The
inspected remote feature still reads it in Core, and surviving dev/net apex detectors disable
cookie writes while retaining reads. Public display-locale helpers also remain, with public route
integration deferred in Edge ADR 019. This investigation does not restore or authorize that dependency.

## Sharing, signing and security review

Domain-scoped transport sends the cookie to more sibling hosts. Inventory every recipient,
including public/asset/third-party-managed hosts, logs, upstream proxies and Edge dispatch before
approving scope. HttpOnly does not prevent those servers from receiving the JWT. Same-site sibling
origins remain separate trust boundaries; CSRF, Origin and Fetch Metadata protections must survive.

The current `__Host-` prefix is incompatible with a `Domain` attribute. A `__Secure-` name could
permit domain scope but would not preserve host-only injection protection. Final naming, duplicate
host/domain cookie precedence, legacy cleanup and subdomain injection defenses remain Open.
The browser constraints are documented by [MDN Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie).

Current shared Rails code requires and exposes Preference private-key material through the registry
and can issue outside Base. The desired physical separation needs evidence of process credentials,
secret mounts, key-service permissions and public-key-only boot behavior. This audit inspected no
secret values and establishes no production credential inventory.

Signed projections establish integrity and provenance, not agreement with present DB state.
[JWT expiration semantics](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.4) cannot by
themselves revoke a copied snapshot early. No encryption/confidentiality guarantee is provided by a
signature. Define claim minimization and residual privacy risk for a long-lived value even when it
has no authentication meaning. A display cookie or JWT consent snapshot is not sufficient evidence
to enable tracking after withdrawal; consent authority/staleness must be settled separately.

## Consistency and QA questions

The discussion calls for stronger QA if display cookies are chosen. QA **does not make multiple
cookies atomic**. A browser can observe mixed generations after partial cookie acceptance, reordered
responses, parallel tabs, quota/deletion or different expiration dates.

Before accepting mixed generations, specify:

- The allowed impact: theme/localization/formatting inconsistencies versus operations that require
  one coherent snapshot. Consent, age policy and authorization cannot be inferred from a mixed UI.
- Detection: whether a representation exposes a coherent version, which mismatches are actually
  observable, and what remains undetectable with independent cookies. No new version-cookie protocol
  is approved here.
- Recovery: the approved source and triggering user action, precedence during convergence, and
  handling of stale responses. Recovery cannot become GET issuance or a hidden refresh mechanism.
- Safe failure: validated bounded display defaults or explicit errors as appropriate, no persistence
  from mirrors, and no consent/security grant from missing, stale or contradictory data.
- Cache behavior: display JSON, SSR, browser HTTP cache, service workers and back/forward history after
  change/reset/sign-out. Existing browser APIs use `no-store`; Core/Warp are excluded from Global's
  default, so family-specific evidence is required. No cache purge or browser-history guarantee has
  been demonstrated in this session.

## Relationship to existing decisions

This record supersedes **none** of the following. Supersession requires the final approved decision.

| Record | Current relationship |
| --- | --- |
| [Preference scope and persistent-state separation](preference-scope-and-browser-persistent-state-separation.md) | Preserve display/usage scope and reserved `continuity`; despite an inconsistent index listing, its body is Accepted and contains no supersession notice. |
| [Soft bubble doctrine](preference-soft-bubble-doctrine.md), [Actor facade](actor-current-facade.md) | Preserve domain/DB separation and facade; authority and hydration amendments supersede historical Sign/IdP and auth `prf` wording. |
| [Cookie scope](cookie-domain-scope-by-surface.md), [browser family capability](preference-browser-transport-family-capability.md) | Current host-only transport and family-local APIs remain governing. Domain sharing/Base-only issuance would require explicit scoped replacement. |
| [Invalid browser credential recovery](invalid-browser-credential-recovery.md) | Preserve failure taxonomy, non-issuing GET/HEAD recovery and concurrency guarantees. Its predecessor is Superseded. |
| [TanStack zero-cookie UI](tanstack-start-zero-cookie-ui-origin-boundary.md) | Preserve Core's UI/Rails boundary; future API ownership changes need an explicit decision. |
| [Theme contract](theme-preference-cookie-and-param-contract.md), [localization flow](localization-preference-flow.md) | Keep stable keys and request overlay separation. Theme API mirror-read drift is recorded, not endorsed. |
| [Re-login record recency](preference-relogin-reconciliation-record-recency.md) | Still marked Accepted; current per-key implementation/docs conflict. Resolve that governance drift independently of TTL selection. |
| [Default no-store](global-and-publishing-default-no-store-policy.md) | Applies to its declared roots; does not establish caching safety for every consumer. |

## Decision status and next decision gate

The supported direction is simplification by retiring dedicated Preference refresh and DBSC. The
complete architecture, 400-day TTL, delivery alternatives, cookie attributes/scope, revocation and
physical key isolation are **not finally approved**. This Proposed record authorizes no code,
schema, configuration, tests, frontend or Edge changes and invalidates no Accepted ADR.

Use approximately three months for continued design review, with explicit resolution of the
lifecycle table, frontend/Edge boundaries, residual risk and observed drift. Once the final design
is approved, record the actual Decision, exact supersession scope and implementation acceptance
conditions. Neither elapsed time nor this ADR's existence constitutes approval to implement.
