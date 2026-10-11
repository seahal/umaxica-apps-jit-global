# Integrated Auth, OIDC, Browser Routes, and Edit Surface Implementation Plan

**Status:** Architecture plan approved for implementation; verification environment remains
blocked.  
**Prepared:** 2026-09-13  
**Scope:** One coordinated implementation project in this Rails repository. No deployment, push, PR,
or external write is included.

## Executive design

Implement the requested architecture as one boundary change:

- Base is the sole deployed Identity Provider and Authorization Server surface. Preserve Acme as the
  existing conceptual authority vocabulary where it names shared services and logout state; update
  the accepted architecture decision to say explicitly that Base is the physical Rails authority
  implementation. Do not rename the application or its databases wholesale.
- Auth is a credential and authentication ceremony service. It no longer acts as an OIDC RP, stores
  RP callback state, exchanges RP tokens, or makes independent authentication policy decisions. It
  may retain actor-specific opaque **ceremony-local** browser sessions; those sessions are not Base
  login sessions, identity/AAL/policy authority, or RP Sessions. Auth cannot grant Base authority.
- Core app/com/org, Side app/com/org, and Edit org are seven distinct OIDC RPs with independent
  client registration, signing keys, callback URI, face identity, browser transaction, and RP
  Session.
- Preserve the current actor-partitioned Base session stores and promote their child TokenUsage rows
  to first-class RP Sessions. Separate durable session revocation from Access JWT expiry.
- Use one structured Valkey layer for authorization codes and the requested development/test
  topology. Keep private_key_jwt replay state in PostgreSQL.
- Make Root the Auth/Base home for the six requested faces; remove Base lobby and those six
  dashboards. Base Root renders the authenticated home under Base authority. Auth Root remains a
  public ceremony-service entry because an Auth ceremony cookie is not proof of Base login. Remove
  Base lobby and consolidate browser termination around /sign/out and a one-shot completion
  representation.
- Keep the Edit Publishing UI and Publishing database where they already are. Close the remaining
  Edit boundary gap: independent Edit OIDC client, Rails-owned RP endpoints, and explicit
  declarations for the 12 route cells.

The project is dependency-ordered below, rather than split into four independent implementations.

## Investigation boundary and baseline

The repository instruction index, applicable
surface/routing/controller/testing/data-shape/migration/no-flash/language/implementation-note rules,
the repository knowledge-tree guidance, current route files, current controller/model/service
references, relevant tests, ADRs, docs, Valkey configuration, and CI scripts were read. The stopping
condition is met: affected code is located, dependencies are known, tests can be selected, and an
implementation order is defined. Further exploratory searching is not needed before the first TDD
phase.

The worktree contains user-owned modified and deleted files, including source and tests. They were
not staged, reverted, formatted, or otherwise changed by this review. During this review, only this
plan file is being updated. Before implementation, inspect status again and restrict edits to
reviewed task files; do not reset, clean, stash, or restore user changes.

| Baseline check   | Result                                                                                                                                                                                                                                     | Classification                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| bin/rails test   | Exited before running tests. Rails could not resolve the configured PostgreSQL host primary during test schema maintenance from test/test_helper.rb. No per-test failure/error list exists because the suite did not reach test execution. | Environment-dependent baseline blocker; not evidence of an application defect, test defect, or flake. |
| bun run test     | Passed: 86 files, 1,077 tests.                                                                                                                                                                                                             | Green baseline; no current JavaScript failure.                                                        |
| bin/rails routes | Did not boot. Loading debug attempted to bind a Unix socket under workspace tmp and was denied with EPERM before route enumeration.                                                                                                        | Environment/sandbox-dependent diagnostic error; not an application route failure or test failure.     |

Do not label the unexecuted Rails tests as pre-existing application failures. Before implementation
verification, provide a reachable test PostgreSQL service named primary and a permitted debugger
socket or the repository-supported way to disable the debugger auto-start. Repeat the baseline
before the first code change in that environment. Any subsequent failing test must be classified
against that successful baseline.

### Revalidation against the current checkout

The canonical plan is tracked at
`plans/backlog/integrated-auth-boundary-surface-consolidation-plan.md`; `plans/README.md` places
proposed future work in `plans/backlog/` and says not to recreate `plans/active/`. The current
worktree includes user-owned edits to Base identity/session controllers and presenters, OIDC/session
tests, other route/security tests, and one deleted result file. Those changes are not part of this
plan correction and must be preserved. Source inspection confirms no new change to OIDC routes,
token exchange, schema, Valkey topology, host routing, or Edit ownership in the inspected diffs.
`docs/security/social-callback-boundary.md` keeps OmniAuth callbacks outside
`authorize!`/`authorized_scope`: sign-in/sign-up have no authenticated record, and link intent is
bound to the signed-in resource through state, provider verification, and session binding. Preserve
that contract. Do not restore deleted audit artifacts or old docs absent from this checkout.

The baseline was repeated against this checkout: `bun run test` passed (86 files, 1,077 tests).
`bin/rails test` stopped during test schema maintenance because PostgreSQL host `primary` could not
be resolved, before any Ruby test ran. `bin/rails routes` stopped while `debug` attempted to bind a
workspace Unix socket and received `EPERM`, before route enumeration. These are environment
blockers, not application test failures. Rails implementation verification is blocked until a
reachable test PostgreSQL service and a permitted debugger socket (or the repository-supported
debugger-disable mechanism) are available. This does not block architecture approval, but must be
resolved before claiming Rails checks green.

## Current-state inventory

### Authority, RP, and token flow

- config/routes/auth.rb describes Auth as a credential gateway, but its app/com/org hosts still
  expose OIDC authorization, callback, and backchannel logout routes. The matching controllers live
  under app/controllers/auth/{app,com,org}/oidc. Auth application controllers include
  OidcSsoInitiator and carry sign-rp client configuration.
- config/routes/base.rb contains the Authorization Server surface under /oauth, and also Base
  /oidc/authorization and /oidc/callback RP routes. Base application controllers still identify as
  base-rails-rp. Therefore the current physical Base app has both authority endpoints and a legacy
  RP role.
- Core and Side expose /oidc/authorization and /oidc/callback. Core also exposes Rails DBSC routes
  while TanStack Start owns normal Core pages. Their logout/backchannel controllers and client
  registration are keyed by shared clients rather than by face.
- Edit already has a Rails host at edit.umaxica.org, development host edit.org.localhost, boot/host
  configuration, standard health and revision routes, and the 12 Publishing management
  controller/page families. Edit::Org::ApplicationController still configures base-rails-rp and
  includes OidcSsoInitiator. Its route file creates the 12 surface/audience route cells with loops.
- app/values/oidc_client_stores_static_client_store.rb currently registers sign-rp, base-rails-rp,
  side-rails-rp, and core-next-rp as shared browser clients, as well as native and content clients.
  build_redirect_uris uses /oidc/callback; the default registered post-logout path is
  /sign/out/complete. Native and content clients have separate responsibilities and must survive
  this refactor.
- app/values/oidc_client_assertion_jwt.rb already enforces ES384, exact token endpoint audience,
  iss=sub=client_id, required claims, key id, signature, expiry, and one-use jti. Assertion lifetime
  is currently five minutes. A 60-second maximum assertion lifetime is a UMAXICA hardening policy,
  not an RFC mandate. Align the accepted-assertion age with the existing 30-second JWT leeway and
  keep SecurityConsumedJti in PostgreSQL with its unique constraint and fail-closed outage behavior.
  The current failure log includes exception message text and should be tightened to category/class
  only.
- app/services/oidc_token_exchange_coordinator.rb authenticates client assertions and consumes
  actor-specific ClientAuthorizationCode, VisitorAuthorizationCode, or OperatorAuthorizationCode
  PostgreSQL rows under locking. The current code stores a raw 32-byte-random URL-safe code and has
  a 10-second expiry. The coordinator checks client, exact registered redirect URI, face, expiry,
  scope and PKCE, then consumes the row while creating the corresponding TokenUsage child session.
  Existing negative tests expect client/redirect/PKCE mismatch to issue no token and leave the code
  unconsumed; preserve that pre-consumption validation contract. Once the atomic issued→consumed
  transition succeeds, every later failure leaves it consumed. app/services/oidc_rp_token_client.rb
  and the existing ID Token verifier are useful adapters/verification code to reuse.
- Current OIDC authorization code persistence is PostgreSQL, unlike the requested Valkey one-time
  code store. Internal ceremony grants/results are also currently represented by JWT value/issuer
  classes; those are separate from OAuth Access/ID/Refresh Tokens and must be changed without
  removing the global OAuth token protocol.

### Identity and session state

- ClientToken, VisitorToken, and OperatorToken are actor-bound, durable session roots with
  refresh/session/binding state. They are stored on distinct app/com/org ticket connections,
  associate to their respective client/visitor/operator, and already represent the Base
  browser-session level for this plan.
- ClientTokenUsage, VisitorTokenUsage, and OperatorTokenUsage include OidcTokenUsage. They already
  hold public_id, oidc_client_id, scope, refresh token digest/family/rotation/expiry, last activity,
  revocation, and logout state. Existing migrations enforce one non-revoked usage per parent token
  and client with a partial unique index. This is the direct basis for renaming these rows to
  ClientRpSession, VisitorRpSession, and OperatorRpSession.
- OIDC access JWTs are not the child Usage rows. Keep each Access JWT short-lived and preserve RFC
  9068 validation. Normal authenticated requests must not acquire an RP Session database lookup as a
  new revocation check. Current `OidcAccessTokenAuthenticator` does query the Usage row and checks
  its active state/JTI before UserInfo authentication; P2/P5 must remove that session-revocation
  dependency from normal Access JWT validation. The configured Access JWT lifetime is five minutes
  (`SecurityTokenLifetimes::AUTH_ACCESS_JWT_TTL`, aliased by `AuthenticationBase::ACCESS_TOKEN_TTL`)
  and the existing RFC 9068 leeway is 30 seconds. Thus a cryptographically valid already-issued JWT
  can remain accepted through `exp` plus the configured leeway after RP Session revoke; it is not
  retroactively invalidated by that revoke.
- `OidcRefreshTokenIssuer` treats reuse of the previous refresh digest as a family compromise and
  revokes that one Usage row, not the parent Base Browser Session or sibling Usage rows. Align
  Authorization Code replay response with this family-level precedent after a code-to-RP Session
  reference is safely linked.
- The Base identity/session management experience exists under Base identity/session controllers and
  Inertia pages. The Base Org session controller is the natural administration entry point for RP
  registry and parent/child session detail; the app/com owner session screens remain actor-scoped.

### Authentication ceremonies and settings

- SignInStateMachine, SignUpStateMachine, the actor-specific Client/Visitor/Operator SignInFlow and
  SignUpFlow models, checkpoint/guardrail sequence, sign-up compensation, and per-surface
  route/controller branches are live and tested. Auth sign-in can currently be entered without a
  Base-issued admission handoff. Org invitation behavior is distinct and must remain so.
- Step-up currently has actor-specific ClientStepUpSession, VisitorStepUpSession,
  OperatorStepUpSession plus actor-specific StepUpCeremonyTransaction models and method branches. It
  already has persisted allowed methods and required scope/AAL, but grant/result handling is
  JWT-oriented and freshness is committed locally by current operations.
- Passkey/TOTP and provider ceremony transactions are actor-specific. App, Com, and Org route/method
  sets are not identical. Google/Apple OmniAuth callbacks and Org Entra callback/settings have
  external URI bindings; preserve those exact callback contracts.
- Auth contains credential-setting and ceremony routes. Base already owns several
  identity/secret/MFA settings routes. Move the Secret Credential settings and MFA
  policy/configuration ownership to Base; leave Secret Credential verification ceremony, Passkey
  settings, TOTP settings where currently supported, Google, Apple, and Org Entra
  ceremonies/settings in Auth.
- Auth .well-known/jwks.json is active Jump/redirect verification infrastructure. It is not the Auth
  OIDC issuer JWKS and must remain.

### Roots and logout

- Auth app/com/org RootsController instances use RootSignInRedirect; Auth’s current Root tests
  expect an unauthenticated permanent redirect to /sign/in. Auth Root sends an authenticated request
  to its after-login destination (currently Base), while its separate DashboardControllers
  authenticate the Client/Visitor/Operator actor and call Action Policy. The former Dashboard is not
  a safe authenticated Auth Root representation once Auth JWT/RP-session authentication is removed.
  An Auth ceremony cookie cannot stand in for Base login; Auth Root will be public in both cookie
  states, with no auto-start or user-specific authority view, and the old Auth Dashboard will be
  retired.
- Base app/com/org RootsController instances use RegionalRootRedirect, send authenticated requests
  to /dashboard, and render a public entry. Base /lobby is the current post-logout anonymous entry.
  Base DashboardControllers inherit FullAccessController / PreAccessController, require the selected
  actor context, authenticate the proper actor, run inherited restricted-session/verification/access
  guards, and call Action Policy.
- Core, Side, and Edit dashboards are outside the six-face /dashboard retirement. Keep them unless a
  separate responsibility is proven absent.
- Auth/Core/Side currently use GET /sign/out/complete, with controller subclasses under
  app/controllers/.../sign/outs/completions. Base instead redirects to /lobby. Auth already has
  SignOutCancellation; Base has no destroy route, and Core/Side route declarations omit destroy.
- SignOutNotice is currently a concern storing its marker in Rails session.
  config/initializers/session_store.rb configures encrypted CookieStore, not a server-side atomic
  session store. The marker has a five-minute TTL and completion Inertia rendering sets
  clear_history: true. Client-side cookie deletion alone cannot guarantee exactly one success under
  two concurrent requests using the same stale cookie; the presentation-only marker will use P3's
  structured Valkey boundary, a digest-keyed/opaque identifier and atomic GETDEL-equivalent consume.
  No PostgreSQL notice tables are justified by audit requirements: logout/audit authority remains in
  AcmeLogoutTransaction and other existing durable records; the notice itself is neither authority
  nor audit evidence.
- OIDC logout uses AcmeLogoutTransactionCoordinator and AcmeLogoutTransaction with a challenged,
  ordered cross-host state machine, exact completion URL allowlisting, and
  browser/fetch-metadata/origin protections. Current steps include origin_cleared, acme_cleared,
  sign_cleared, and finalized. Removing Auth as an RP removes the sign_cleared RP hop; do not remove
  the one-shot challenge, ordering, origin checks, or authoritative Base logout.
- app/values/oidc_client_registry.rb validates post_logout_redirect_uri by exact registered value
  and realm. Retain that check. Existing completion path construction and the Base lobby destination
  must change together.

### Valkey, routes, and Edit ownership

- Development Compose has separate valkey-cache and valkey-rate-limit services/volumes.
  CACHE_REDIS_URL and RATE_LIMIT_REDIS_URL are distinct; test rate limits/cache default away from a
  shared live Valkey. Production configuration requires separate purpose URLs.
- Current Gemfile.lock pins redis-client 0.30.1 and has no hiredis-client. The target Valkey
  one-service/four-or-six logical DB layout directly conflicts with accepted physical-separation
  ADRs.
- Auth has /web/v0 UI endpoints and app/com/org /edge/v0/token/check and /edge/v0/token/dbsc. No
  Auth refresh route is declared there. AuthenticationBase has Auth route helpers for DBSC
  registration, and many checks are contract/security tests. Base /edge/v0/token/check and /dbsc,
  Core /edge/v0/token/refresh and other Base/Core token contracts have independent uses. Do not
  delete the namespace globally. Replace the Auth-specific JWT-session endpoint behavior only after
  its new opaque session API contract is live.
- Edit’s current Publishing controllers and pages are already under
  app/controllers/edit/org/publishing and src/pages/edit/org/publishing. The 4 × 3 matrix and
  management lifecycle tests are already under Edit. No active Base.Org Publishing
  controller/page/test ownership appeared in the route/file search.
  docs/architecture/publishing-persistence.md already describes edit.umaxica.org as the management
  host. Preserve the Publishing tables, queries, policies, operations, public /api/v0/entries API,
  and operator provenance IDs.

## Requirement matrix and traceability

The four pasted request blocks are assigned stable identifiers below. Each row maps to the
integrated workstream and phase that will satisfy it. The plan is not a four-prompt execution list;
it follows shared authority, session, protocol, and route dependencies.

| ID      | Source                        | Requirement integrated into                                                                                                                                                                                       | Workstream / phase |
| ------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| REQ-001 | Block 1, section 1            | Base authority; Auth not RP; seven isolated client IDs/keys/redirects/faces/browser transactions/RP Sessions.                                                                                                     | W1, W4 / P1, P5    |
| REQ-002 | Block 1, section 2            | Canonical RP GET /sign/in and /sign/in/callback, exact URI registry, fail-closed host routing; Core callback owned by Rails.                                                                                      | W4 / P5            |
| REQ-003 | Block 1, section 3            | Pure lib/umaxica/oidc_rp protocol values; thin Rails adapters; no private-method testing.                                                                                                                         | W4 / P5            |
| REQ-004 | Block 1, section 4            | Authorization Code + PKCE S256 for all seven RPs; independent state, nonce, verifier per request.                                                                                                                 | W4 / P5            |
| REQ-005 | Block 1, section 5            | Bounded encrypted per-transaction RP cookie, max four, five-minute TTL, host-only attributes; cookie deletion is cleanup, not one-use enforcement. Base code CAS and callback-write atomicity enforce single-use. | W4 / P5            |
| REQ-006 | Block 1, section 6            | Same-origin safe return_to validation and open-redirect contracts.                                                                                                                                                | W4 / P5            |
| REQ-007 | Block 1, section 7            | Digest-keyed Valkey code store with TTL and atomic issued→consumed tombstone; distinguish replay from unknown/expired while linked family is live; no token on failure.                                           | W3, W4 / P3, P5    |
| REQ-008 | Block 1, section 8            | Independent first-party ES384 private_key_jwt keys and exact claims/audience; ≤60-second lifetime is UMAXICA hardening policy, not an RFC requirement.                                                            | W4 / P5            |
| REQ-009 | Block 1, section 9            | Keep assertion JTI replay prevention in PostgreSQL with unique-index concurrency and fail-closed outage behavior.                                                                                                 | W4 / P5            |
| REQ-010 | Block 1, section 10           | Identity → Base Browser Session → per-client RP Session hierarchy.                                                                                                                                                | W2 / P2            |
| REQ-011 | Block 1, section 11           | Rename TokenUsage models/tables/associations/services/tests to actor-specific RP Sessions; retain partial unique constraint.                                                                                      | W2 / P2            |
| REQ-012 | Block 1, section 12           | Separate Identity/Base Browser/RP Session revoke scope; RP revoke stops future refresh/issuance without sibling revoke or retroactive Access JWT invalidation; normal JWT auth has no RP Session lookup.          | W2 / P2            |
| REQ-013 | Block 1, section 13           | Separate static RP Registry status from Identity/Browser/RP Session state in Base Org management.                                                                                                                 | W2 / P2            |
| REQ-014 | Block 1, section 14           | One development/test Valkey service and one volume using logical DBs 0–5 and responsibility URLs.                                                                                                                 | W3 / P3            |
| REQ-015 | Block 1, section 15           | One structured Valkey adapter/store boundary for connection, namespace, JSON schema, TTL, errors, and atomic calls.                                                                                               | W3 / P3            |
| REQ-016 | Block 1, section 16           | Add hiredis-client without redis-client downgrade and prove selected driver through documented API/runtime test.                                                                                                  | W3 / P3            |
| REQ-017 | Block 1, section 17           | Suite/worker/test Valkey namespacing, ensure cleanup, TTL residue bound, no FLUSH, real atomicity concurrency tests.                                                                                              | W3 / P3            |
| REQ-018 | Block 1, section 18           | Security negatives include replay/tombstone, no RP Session lookup on normal JWT auth, Auth-session non-authority, fail closed, and no secret leakage.                                                             | W2–W5 / P2–P7      |
| REQ-019 | Block 1, section 19           | No persistent RP login state until validation passes; encrypted transaction cookie is replayable browser state, not atomic one-use.                                                                               | W4 / P5            |
| REQ-020 | Block 1, section 20           | Preserve RFC 9068 Access JWT and ES384; normal auth/whoami is JWT-only for RP Session validity, with no request-time RP Session lookup.                                                                           | W4 / P5            |
| REQ-021 | Block 1, section 21           | Remove Auth RP callback/state/token exchange/backchannel client configuration; keep other Auth responsibilities.                                                                                                  | W1, W4 / P1, P5    |
| REQ-022 | Block 1, section 22           | Direct final schema edits for unshipped migrations, no aliases/dual write, controlled local DB recreate.                                                                                                          | W2–W4 / P2–P5      |
| REQ-023 | Block 1, section 23           | Red → Green → Refactor per vertical slice after characterization; public contract tests only.                                                                                                                     | All / P1–P9        |
| REQ-024 | Block 1, section 24           | Keep existing coverage gates; run Rails, coverage, static/style/security, frontend and CI-equivalent checks.                                                                                                      | W7 / P9            |
| REQ-025 | Block 1, section 25           | Supersede conflicting authority/Valkey/logout ADRs and align security/architecture/operations docs.                                                                                                               | W7 / P1, P9        |
| REQ-026 | Block 1, section 26           | Use the listed OIDC/session/models/migrations/config/compose/ADR sites and global call-site search evidence.                                                                                                      | W0 / P0            |
| REQ-027 | Block 1, section 27           | All seven independent RP flows, auth/session boundaries, security tests, docs, coverage, static and full-suite acceptance.                                                                                        | All / P9           |
| REQ-028 | Block 2, section 1            | Base owns WHO/WHETHER/WHY; Auth owns HOW ceremony and has no policy authority.                                                                                                                                    | W1 / P1            |
| REQ-029 | Block 2, section 2            | Remove Auth RP route/state/token exchange dependencies only; retain global OAuth/OIDC, RFC 9068, refresh and logout protocol.                                                                                     | W1, W4 / P1, P5    |
| REQ-030 | Block 2, section 3            | Opaque Base→Auth handoff: 256-bit, digest-only, 60s, atomic, fixed destination, no-store/referrer controls, clean redirect.                                                                                       | W1 / P4            |
| REQ-031 | Block 2, section 4            | Keep current SignIn/SignUp state machine and App/Com/Org branches; require Base admission; preserve Org invitation flow.                                                                                          | W1 / P4            |
| REQ-032 | Block 2, section 5            | One StepUp state machine/session per actor storage boundary; credential methods branch on one rail.                                                                                                               | W1 / P4            |
| REQ-033 | Block 2, section 6            | Keep Passkey/TOTP/Google/Apple/Entra settings in Auth; Secret Credential settings and MFA policy in Base.                                                                                                         | W1 / P4            |
| REQ-034 | Block 2, section 7            | No polymorphic/STI/type/flow/purpose-discriminator flow table; explicit flow/session models and tables.                                                                                                           | W1 / P2, P4        |
| REQ-035 | Block 2, section 8            | Actor-specific short-lived ceremony-local `__Host-auth_sid` sessions; no Base login, identity, policy, AAL, or RP authority; Base handoff required for each protected new flow.                                   | W1 / P4            |
| REQ-036 | Block 2, section 9            | Conditional atomic state transitions/CAS, finite lease only if required, terminal states irreversible.                                                                                                            | W1 / P4            |
| REQ-037 | Block 2, section 10           | Auth→Base result codes use purpose/actor-specific opaque digest records, single-use and 60s.                                                                                                                      | W1 / P4            |
| REQ-038 | Block 2, section 11           | Inertia same-origin UI APIs under /api/v0, no JS bearer tokens, CSRF retained; health/revision contracts preserved.                                                                                               | W5 / P4, P8        |
| REQ-039 | Block 2, section 12           | Keep App Google/Apple and Org Entra callback/binding contracts; preserve link/unlink step-up gates.                                                                                                               | W1 / P4            |
| REQ-040 | Block 2, section 13           | Keep Auth .well-known/jwks.json and Jump/redirect signing contracts untouched.                                                                                                                                    | W7 / P1, P9        |
| REQ-041 | Block 2, section 14           | Base owns authoritative logout; Auth /sign/out performs ceremony-cookie cleanup or fixed redirect only.                                                                                                           | W5 / P7            |
| REQ-042 | Block 2, section 15           | Inventory all Auth routes; keep operational/presentation/external protocol routes; move durable management UI only where required.                                                                                | W5 / P1, P4        |
| REQ-043 | Block 2, section 16           | Prove /edge/v0/token callers before retiring Auth-specific JWT endpoints; retain shared Base/Core APIs.                                                                                                           | W5 / P4            |
| REQ-044 | Block 2, section 17           | TDD characterization, atomic/replay/CSRF/provider/JWKS/root route contracts; migration after failing tests.                                                                                                       | All / P1–P9        |
| REQ-045 | Block 2, section 18           | Read the current routes/controllers/state/provider/OIDC/token/jump test graph before implementation.                                                                                                              | W0 / P0            |
| REQ-046 | Block 2, section 19           | This plan supplies current inventory, target boundary, data/state/protocol/route/phase/test/risk/open-question sections.                                                                                          | W0 / P0            |
| REQ-047 | Block 2, section 20           | Planning phase is read-only; after plan approval, implement without generic tables, JWT session, Auth RP, JWKS deletion, or unrelated refactor.                                                                   | W0 / P0            |
| REQ-048 | Block 3 Part A                | Canonical Root on six Auth/Base faces; Base authenticated Root preserves former Dashboard, while Auth Root stays public because Auth ceremony state is not Base login.                                            | W5 / P6            |
| REQ-049 | Block 3 Part A                | Remove early sign-in/regional redirects, preserve ri normalization, use existing flash display only, prevent shared cache.                                                                                        | W5 / P6            |
| REQ-050 | Block 3 Part B                | Remove /dashboard route/controllers/pages/tests on six faces after links move; do not affect Core/Side/Edit dashboards.                                                                                           | W5 / P6            |
| REQ-051 | Block 3 Part C                | Remove Base /lobby and route anonymous entry to Base Root; no replacement landing resource.                                                                                                                       | W5 / P6            |
| REQ-052 | Block 3 Part D                | Align show/new/edit/create/destroy on browser /sign/out; destroy is pending-ceremony cancellation only.                                                                                                           | W6 / P7            |
| REQ-053 | Block 3 Part E                | GET /sign/out atomically consumes a five-minute Valkey presentation capability only; no authority mutation; invalid/revisit is 404; clear Inertia history.                                                        | W6 / P7            |
| REQ-054 | Block 3 Part F                | Remove browser /sign/out/complete and update every helper, coordinator, URI registry, test, route exception and doc.                                                                                              | W6 / P7            |
| REQ-055 | Block 3 Part G                | Preserve logout challenge/CAS/order, stale-cookie safety, exact redirects, cross-host protections, and no GET authority mutation.                                                                                 | W6 / P7            |
| REQ-056 | Block 3 Part H                | Keep explicit controller behavior, policies, small interfaces, no route metaprogramming or implicit callbacks.                                                                                                    | All / P2–P8        |
| REQ-057 | Block 3 Part I                | Add/update Root, logout, OIDC, route, cache, authorization and history tests before implementation.                                                                                                               | W5, W6 / P6, P7    |
| REQ-058 | Block 3 Parts J–K             | Update authoritative logout/routing/root docs and run full relevant Rails, frontend, browser and CI checks.                                                                                                       | W7 / P9            |
| REQ-059 | Block 4 Primary target        | Keep Edit as first-class edit.umaxica.org; current host/boot/Host Authorization is already present.                                                                                                               | W5 / P8            |
| REQ-060 | Block 4 Publishing move       | Keep the 12 explicit Publishing management controllers/pages and lifecycle; preserve Publishing DB/domain.                                                                                                        | W5 / P8            |
| REQ-061 | Block 4 Base ownership        | Ensure Base.Org has no Publishing management route/page/controller; current search found no active Base UI copy.                                                                                                  | W5 / P8            |
| REQ-062 | Block 4 operational endpoints | Preserve Edit revision, health/probes and machine-readable endpoint contracts already present.                                                                                                                    | W5 / P8            |
| REQ-063 | Block 4 auth/authz            | Preserve active operator and Action Policy guard; do not make Cloudflare Access the authorization mechanism.                                                                                                      | W5 / P8            |
| REQ-064 | Block 4 host/config           | Keep PUBLIC_EDIT_STAFF_URL, boot host, host authorization, development hostname and examples aligned.                                                                                                             | W5 / P8            |
| REQ-065 | Block 4 Inertia/React         | Keep Edit-owned Publishing components and update contract tests if the OIDC/RP route moves.                                                                                                                       | W5 / P5, P8        |
| REQ-066 | Block 4 implementation style  | Replace Edit’s route-generation loops with explicit declarations; add no new broad Concern or generated methods.                                                                                                  | W5 / P8            |
| REQ-067 | Block 4 future coupling       | Keep Publishing DB/domain isolated from Base identity; no cross-DB FK/association/transaction or Base assumptions.                                                                                                | W5 / P8            |
| REQ-068 | Block 4 tests                 | Preserve 12-cell, lifecycle, authorization, health, host, inventory, and Publishing persistence tests.                                                                                                            | W5 / P8            |
| REQ-069 | Block 4 docs/completion       | Update Edit/Pub architecture and security docs and retain evidence only after actual checks run.                                                                                                                  | W7 / P9            |
| REQ-070 | Outer planning request        | Complete and verify one integrated plan before implementation; preserve baseline classification and REQ traceability. P0 stays read-only.                                                                         | W0 / P0            |

## Root causes and overlaps

1. **Authority-role drift is the central cause.** Auth is described as a credential gateway but
   still has three OIDC RP route/controller sets and a shared sign-rp client. Base is the OAuth
   authority and also has a Base RP callback. The client registry combines multiple hosts/faces
   under base-rails-rp, side-rails-rp, and core-next-rp. Consequences include Auth-owned OIDC
   session state, confusing logout sequencing, host-derived callback behavior, and no per-face
   session boundary.
2. **There are two distinct one-time-code domains that must not be conflated.** OAuth Authorization
   Codes are currently stored in PostgreSQL and must move to Valkey. Base→Auth handoff and Auth→Base
   ceremony result codes are internal authority messages and must remain purpose-specific,
   digest-only PostgreSQL records. Existing signed ceremony grant/result JWTs are not OAuth tokens.
3. **Session state is already split but poorly named.** The TokenUsage child rows already implement
   per-RP refresh/session lifecycle and the correct parent/client partial unique index. The
   conceptual hierarchy exists in the data shape but is obscured by “usage” naming and UI.
4. **Browser route concepts drifted.** Auth/Base roots redirect, Base lobby is an alternate
   anonymous home, six Auth/Base dashboard routes duplicate root semantics, and completion paths
   differ between Base and Auth/Core/Side. Static OIDC post-logout registration and coordinator
   helper-name construction encode the old paths.
5. **Valkey decisions are internally contradictory.** Code config already has purpose-separated
   cache/rate-limit URLs; accepted ADRs reject logical DB separation while the supplied target
   mandates one nonprod service and six logical DBs. A new decision must state that logical DBs and
   prefixes are organizational namespace, not security boundaries.
6. **Edit is largely migrated already.** Host, operational endpoints, explicit controllers/pages and
   management tests exist under Edit. Remaining gaps are shared Base RP identity, missing Edit’s
   independent OIDC client/callback/logout contract, and route loops that manufacture the 12 cells.
7. **Shared logout currently treats Auth as an RP hop.** The ordered transaction includes
   sign_cleared. Removing Auth as an RP means shortening that sequence, while retaining the
   transaction challenge, exact destination allowlist, Origin/Fetch Metadata protections, and Base
   authority mutation.

## Overlap, conflicts, and their resolution

| Conflict or overlap                                              | Current evidence                                                                                                                                                                                                                                                            | Integrated resolution                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Blocks 1–2 authority redesign vs Block 3 logout-task boundary    | Blocks 1–2 require Base to own identity/session/policy and be the only IdP/AS, while Block 3 says its logout/root task is not an IdP/AS migration and must not redefine authority ownership.                                                                                | These cannot both govern the whole project literally. Apply the explicit project-wide Base/Auth target from Blocks 1–2; constrain Block 3 to route/logout integration. Preserve its authoritative logout security behavior, exact URI validation, challenge/order, Origin/Fetch Metadata checks and no-GET-authority-mutation rule. Do not rename or relocate Acme databases/services or broaden unrelated OIDC endpoints.                                                                                                                               |
| Accepted authority ADR vs Base sole IdP/AS target                | adr/acme-sign-core-base-port-boundary.md says Acme is sole IdP/AS and Base is an RP; adr/sign-residual-idp-surface-retirement.md keeps Sign as an RP.                                                                                                                       | New ADR explicitly supersedes the conflicting runtime role statements: Base is the physical sole authority surface; Auth is ceremony-only. Keep Acme vocabulary for conceptual shared authority services and existing data/logging names unless a separate rename is approved. Never run two authorities.                                                                                                                                                                                                                                                |
| Accepted logout/root ADRs vs requested canonical paths           | adr/logout-ceremony-boundary.md says /sign/out/complete is reloadable; adr/base-lobby-unauthenticated-entry.md makes /lobby anonymous home and Base completion destination.                                                                                                 | Replace with one-shot /sign/out and Root home. Mark both accepted ADRs amended/superseded for these paths. Preserve challenge validation and exact URI validation.                                                                                                                                                                                                                                                                                                                                                                                       |
| Auth authenticated Root vs ceremony-only Auth                    | Current Auth Root redirects after actor authentication; its separate Dashboard is actor/JWT authenticated. The Root request asks for the former Dashboard when authenticated, while Auth must not treat a local ceremony cookie as proof of Base login or policy authority. | Resolve in favor of the fixed authority boundary. Base app/com/org Root keeps the authenticated former Dashboard under the same FullAccess/restricted/verification/Action Policy chain. Auth app/com/org Root is a public ceremony-service entry for every local cookie state: no actor-specific props, no Base-login claim, no auto-start, and no redirect loop. Retire Auth Dashboards. Auth may resume only the specific admitted ceremony bound to a valid ceremony-local session; every new protected ceremony still requires fresh Base admission. |
| Auth sign-out vs no Auth RP                                      | Requested common route shape includes Auth, but Auth no longer owns an RP session or authoritative logout.                                                                                                                                                                  | Auth /sign/out only cancels its own active Auth ceremony/session and may display a one-shot “Auth ceremony ended” representation. It never claims that Base/RP sessions were revoked. A fixed 303 to Base sign-out is allowed where the request means global sign-out.                                                                                                                                                                                                                                                                                   |
| RP-only revoke vs OIDC RP-Initiated Logout                       | RP Session revocation must not affect siblings, while current OIDC end-session flow can revoke Base authority session and coordinate logout.                                                                                                                                | Keep the two commands distinct. Administrative/revoke-RP-session affects one child row only. OIDC RP-Initiated Logout continues its existing authority-owned end-session semantics and cross-host coordination. Test each separately.                                                                                                                                                                                                                                                                                                                    |
| CookieStore notice vs strict one-shot show                       | Rails session is encrypted CookieStore, so concurrent requests with the same stale cookie can both see a client-carried notice.                                                                                                                                             | Keep the existing five-minute SignOutNotice behavior but place the capability in P3's structured Valkey auth-state namespace. Use a digest-keyed opaque reference, actor/face binding, and atomic single consume. Do not add three durable PostgreSQL notice tables: the marker is not auth, logout, or audit authority; AcmeLogoutTransaction remains the durable security record. Valkey failure rejects the completion representation as 404 without changing authority state.                                                                        |
| Edit authentication instruction vs seven-RP target               | Edit request says not to redesign authentication, while the earlier target explicitly requires Edit org as an independent first-party RP.                                                                                                                                   | Apply the global architecture only to the RP boundary. Keep Edit’s current operator authentication/Action Policy and Publishing behavior; replace shared base-rails-rp with edit-org. Do not refactor Publishing identity/domain or build another auth system.                                                                                                                                                                                                                                                                                           |
| No-flash repository rule vs Root entry requirement               | Existing Auth/Base layouts already render the shared flash partial; the no-flash rule forbids adding flash writers or new flash transports.                                                                                                                                 | Reuse only the current layout transport if content is already present. Do not introduce flash writes, new shared props, or new flash regions. Render all new validation/success outcomes inline.                                                                                                                                                                                                                                                                                                                                                         |
| Palm placeholder vs browser completion retirement                | Logout ADR mentions a future Palm /sign/out/complete app link, but current Palm logout is not implemented; Palm is excluded from browser-shape normalization.                                                                                                               | Remove browser /sign/out/complete routes and references for Auth/Base/Core/Side/Edit. Do not add a Palm browser flow. Replace the stale Palm future-path text with “future native logout target undecided”; keep Palm native routes/contracts unchanged.                                                                                                                                                                                                                                                                                                 |
| Current two physical Valkey stores vs six logical DBs            | Accepted valkey-cache-and-rate-limit-stores ADRs reject logical DB separation.                                                                                                                                                                                              | New ADR supersedes those isolation claims for development/test only. Keep production responsibility URLs separate as configured; explicitly document that logical DBs do not isolate security or persistence failure domains.                                                                                                                                                                                                                                                                                                                            |
| Existing Auth edge endpoints vs global token infrastructure      | Auth exposes check/dbsc; Base and Core have their own token/dbsc/refresh clients and route contracts. Search found shared AuthenticationBase route helpers and boundary tests.                                                                                              | Migrate Auth-specific session checks to Auth /api/v0 opaque-session endpoints, then remove only obsolete Auth JWT check/dbsc paths. Keep Base/Core/shared OAuth, Access JWT, refresh, DBSC and Palm contracts until direct callers and tests prove otherwise.                                                                                                                                                                                                                                                                                            |
| Publishing route matrix loop vs explicit declaration requirement | config/routes/edit.rb currently loops over four surfaces and three audiences. Controllers are already explicit.                                                                                                                                                             | Replace only the route loop with 12 ordinary declarations, retaining every named URL and controller mapping. No dynamic host/surface/audience inference.                                                                                                                                                                                                                                                                                                                                                                                                 |

## Adopted integrated design

### Trust and responsibility boundaries

| Classification | Responsibilities                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| KEEP IN AUTH   | App/com/org credential ceremonies; SignIn/SignUp state machines and their existing actor/surface branches; Passkey ceremony/settings; TOTP where currently supported; App Google/Apple; Org Entra; Secret Credential authentication ceremony; short-lived actor-specific AuthCeremonySession (ceremony-local only, never Base login/session/policy/AAL authority); operational health/revision/CSP/PWA/robots/sitemap/Apple notifications as current contracts require; Jump/redirect .well-known/jwks.json. |
| MOVE TO BASE   | Identity, browser session, session policy, MFA policy/settings, Secret Credential settings, sign-in/up/step-up admission, authoritative apply of ceremony results, RP registration administration and Base session hierarchy management.                                                                                                                                                                                                                                                                     |
| REPLACE        | Shared browser clients with seven clients; /oidc/callback RP starts with /sign/in and /sign/in/callback; signed Auth handoff/results with opaque purpose-specific codes; PostgreSQL OAuth authorization codes with Valkey; TokenUsage names with RP Session names; Auth API /web/v0 with /api/v0; six Auth/Base root/dashboard/lobby paths with one Root contract; reusable completion routes with one-shot /sign/out.                                                                                       |
| RETIRE         | Auth OIDC authorization/callback/backchannel RP roles and sign-rp registration/keys; Base RP-only /oidc/authorization and /oidc/callback and base-rails-rp registration; shared core-next-rp and side-rails-rp browser identities; old authorization-code tables; TokenUsage names; six Auth/Base /dashboard routes; Base /lobby; browser /sign/out/complete and nested completion controllers; obsolete cookie OIDC RP transaction keys and old web/v0 endpoint copies after callers migrate.               |

Root consequence: Base app/com/org Root keeps the authenticated former Dashboard behavior and its
complete inherited authorization chain. Auth app/com/org Root is always a public, non-user-specific
ceremony-service entry. It does not infer Base authentication from `__Host-auth_sid`; the former
Auth Dashboard is retired. This is the explicit resolution of the conflicting Root and authority
requirements.

Keep Base /oauth authorization, token, JWKS, revocation, userinfo, discovery, and OIDC end-session
authority routes. Keep Core/Side/Edit RP backchannel logout as required by registration. Keep Auth
Apple server notifications, OmniAuth callbacks, health/revision, PWA and Jump JWKS. Do not remove
global OIDC because the Auth RP disappears.

### Data model and persistence plan

No new persistence may use polymorphic associations, STI, type/*_type columns, flow_type,
subject_type, purpose-as-flow discriminator, generic auth_flows, or generic auth_sessions. Common
Ruby transition/serialization behavior is allowed without implicit inclusion hooks. Every concrete
table has one responsibility and one actor/surface boundary.

| Responsibility                      | Current                                                                                                                  | Planned final model/table contract                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Identity                            | Client, Visitor, Operator and their separate principal records                                                           | Keep these actor-specific identities. Use existing stable public identifiers across service boundaries; do not introduce a universal polymorphic identity row or cross-database association.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Base Browser Session                | ClientToken, VisitorToken, OperatorToken, each in its actor ticket DB and bound to its actor                             | Retain these as the existing actor-specific Base Browser Session backing rows for the first cut. Their public_id remains the opaque internal reference. Do not reinterpret them as OIDC Access JWTs.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Auth ceremony-local browser session | Auth currently authenticates with JWT-backed actor tokens and Rails CookieStore state                                    | Add distinct `ClientAuthCeremonySession`, `VisitorAuthCeremonySession`, and `OperatorAuthCeremonySession` records in their matching actor ticket DB. `__Host-auth_sid` contains only a 256-bit-or-stronger random identifier; store only its digest plus created/expiry/revoked timestamps. Keep state short-lived and link specific actor flow rows to the concrete session with ordinary non-polymorphic FKs. Store no role, permission, policy result, AAL, Base login status, or RP Session. Do not query/introspect Base Browser Session on each Auth request. An optional Base session reference belongs only to an admitted handoff/result transaction as correlation and cannot prove authority.                                                                                                                                                                                                                                         |
| RP Session                          | ClientTokenUsage / VisitorTokenUsage / OperatorTokenUsage                                                                | Rename to ClientRpSession / VisitorRpSession / OperatorRpSession, tables and associations likewise. Rename OidcTokenUsage to RpSession concern. Retain scope, public_id, client_id, refresh family/digests/rotation/expiry, DPoP/binding, last activity, revoke and logout fields. Access JWTs remain stateless, short-lived values.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Active RP Session uniqueness        | Existing partial unique index on parent token + oidc_client_id where revoked_at is null                                  | Retain as a database partial unique index with final rp_session table/column names. Keep friendly model validation as secondary; concurrency test the database constraint.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Auth state machine data             | Actor-specific Client/Visitor/Operator SignInFlow, SignUpFlow, StepUpSession, and StepUpCeremonyTransaction              | Reuse these models and transitions. Add explicit handoff/result digest fields to the existing purpose-specific transaction where that object owns the same flow lifecycle, or add a named actor-specific handoff table only where no matching transaction exists. Use separate sign-in, sign-up, and step-up rows; never combine through a discriminator. App/Com/Org stay in their matching ticket DB.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Base admission/result code          | OIDC authorization transactions currently contain raw login_challenge; ceremony grants/results are currently signed JWTs | Replace raw challenge with a 256-bit random code whose SHA-256 digest is stored. Use distinct purpose-specific sign-in, sign-up, and step-up handoff/result lifecycle records, actor/surface-bounded. The record may carry separate handoff and result digests because both belong to that one flow transaction. Add conditional consume timestamps/state and 60-second expiry; never persist raw codes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| OAuth Authorization Code            | ClientAuthorizationCode / VisitorAuthorizationCode / OperatorAuthorizationCode tables in PostgreSQL                      | Remove these models/tables after Valkey contract/concurrency tests. Keep the 32-byte CSPRNG code high-entropy and its current 10-second issued TTL. Key by a SHA-256 digest; never store raw code. P3 store exposes fixed-schema JSON and atomic `issued -> consumed` CAS with distinct replay vs unknown/expired outcomes, not GETDEL alone. The consumed tombstone records only consumed_at, public client/RP face, state (linked/pending/replay-seen), and the minimum RP Session reference needed for family revocation. After a successful grant, expire the tombstone no later than the earlier of linked refresh-family expiry and parent Base Browser Session absolute expiry; remove it on family revoke where practical. This is finite online security state, not an audit record. A token-endpoint validation mismatch before CAS leaves the code issued as current tests require; once CAS succeeds, no later error can restore it. |
| private_key_jwt JTI                 | SecurityConsumedJti / security_consumed_jtis in PostgreSQL                                                               | Keep table and unique constraint. Keep Postgres as source of replay prevention; unavailable database means reject assertion. Remove exception messages from logs.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Logout challenge                    | AcmeLogoutTransaction and its ordered state machine                                                                      | Keep same purpose-specific transaction and audit/security contract. Revise its step sequence to remove Auth-as-RP clearing. Retain one-shot logout challenge and terminal CAS; do not retitle the shared conceptual Acme contract only because Base hosts authority routes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Sign-out notice                     | SignOutNotice concern writes marker into encrypted CookieStore                                                           | Keep its five-minute TTL and presentation contract, but place marker data in a dedicated P3 structured Valkey `auth_state:sign_out_notice` namespace. Browser cookie/session holds only an opaque random notice id (Valkey key uses its digest); payload binds actor and face and has strict schema. Atomic GETDEL-equivalent consume is the only permitted GET mutation. No per-actor PostgreSQL notice tables: the marker is neither auth/logout authority nor audit evidence; logout authority remains in AcmeLogoutTransaction. Valkey outage/corruption rejects as 404 and changes no authority data.                                                                                                                                                                                                                                                                                                                                       |
| Publishing                          | Publishing domain, query, forms, operation, policy, revisions, and publishing database                                   | No schema or model change. Keep domain free of Base controller/identity relationships. Preserve operator provenance as the existing stable identifier.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

The current ticket schema is partitioned across db/app_tickets_migrate, db/com_tickets_migrate,
db/org_tickets_migrate and their generated schemas. Since the supplied premise is unshipped, revise
existing migrations directly and remove obsolete AuthorizationCode migrations/models rather than
adding compatibility rename chains. Recreate local development databases only after verifying the
target environment is nonproduction. Never run drop/clean against a shared or production database.

### State machine plan

| Flow             | Existing/new                                                                                                                                                                                                                      | Single state rail and guardrails                                                                                                                                                                                                                                                                                                                  |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SignIn           | Keep SignInStateMachine, Client/Visitor/OperatorSignInFlow, participants, credential verification, selector/checkpoint and session-limit paths. Add Base admission as mandatory entry.                                            | Base admission issued → Auth handoff redeemed → existing surface-specific credential/guardrail/checkpoint branches → verified outcome → opaque SignIn result issued → Base atomically redeems/applies → Auth flow terminal. Failure/denial/expiry/cancel are terminal. Keep App/Com/Org method differences.                                       |
| SignUp           | Keep SignUpStateMachine, actor-specific SignUpFlow, compensation, checkpoints, requirements and Org invitation path. Require admission before Auth starts.                                                                        | admitted → contact pending → contact verified → optional App social callback → guardrail pending → checkpoint pending/requirements clear → finalizing → finalized → Base applies opaque result → completed. Failure, expiry, cancellation remain terminal. Org invitations remain a separate admission reason/branch, not ordinary public signup. |
| StepUp           | Keep actor-partitioned storage if DB connections require it; make one StepUpStateMachine contract, not method-specific session models. Base decides required scope/AAL and allowed methods and issues handoff only when required. | admitted → pending/method selection → credential branch (passkey/TOTP/email OTP where current face allows) → atomic verification/result issue → Base redeem/commit → completed. Cancelled/expired/failed/revoked are terminal. One row/rail may change method only before verification; CAS prevents two concurrent verifiers succeeding.         |
| Passkey Settings | Reuse existing Passkey ceremony transaction and WebAuthn challenge contracts.                                                                                                                                                     | Base admission where needed → issue registration/assertion challenge → verify RP ID/origin/challenge on Auth → update Auth-owned passkey setting → consumed. Challenge cannot be replayed; preserve exact Auth host and WebAuthn RP/origin.                                                                                                       |
| TOTP Settings    | Reuse current actor-specific TOTP ceremony transaction only on faces where current route allows TOTP.                                                                                                                             | Base admission for settings policy → pending enrollment → secret confirmation → active; rotation/removal follow existing verified route. No surface gains TOTP methods just through consolidation.                                                                                                                                                |
| Google Settings  | Keep App Google provider settings and binding state explicit; no generic SocialSettings table.                                                                                                                                    | Base-admitted settings entry → provider-bound authorization state → exact existing Google callback → link/unlink result applied under existing step-up guard → terminal.                                                                                                                                                                          |
| Apple Settings   | Keep App Apple settings and notification callback bindings explicit.                                                                                                                                                              | Base-admitted entry → exact Apple provider callback and state binding → link/unlink result under existing step-up guard → terminal. Preserve Apple server notifications and their signature contract.                                                                                                                                             |
| Entra Settings   | Keep Org Entra-only setup and operator binding.                                                                                                                                                                                   | Base-admitted Org entry → exact Entra callback/failure routes → verified binding update → terminal. Preserve existing Org-only behavior and callback URI.                                                                                                                                                                                         |

The common state transition service may implement CAS, expiry, revoke, and terminal-state checks,
but each flow class owns its state names, legal events, and persistence. Controllers call named
operations; they do not issue arbitrary update!(state: ...).

### Protocol sequences

#### RP sign-in

1. A user requests GET /sign/in on one of the seven RP hosts. A host-scoped Rails controller
   resolves exactly one static client record; unknown host/client fails closed.
2. The RP validates return_to as same-origin relative path, creates fresh state/nonce/code_verifier,
   derives an S256 challenge, and writes a short-lived encrypted transaction cookie unique to this
   browser transaction. Cookie data includes version, RP face, state, nonce, verifier, safe
   return_to, issued_at, expires_at. Limit the host to four active transaction cookies and delete
   expired cookies. Attributes: Secure, HttpOnly, SameSite=Lax, Path=/, no Domain. This encrypted
   cookie is replayable browser state: deleting it on callback is cleanup only and is not an atomic
   one-use guarantee.
3. RP redirects to Base /oauth/authorize with exact registered absolute redirect_uri, state, nonce,
   PKCE S256 challenge/method, scope, and client_id. Host authorization and client registration do
   not use wildcard or dynamic host matching.
4. Base checks static client registration, exact redirect URI, face/realm, enabled state, policy,
   browser session and step-up requirements. If ceremony is required, Base issues a purpose-specific
   opaque Auth handoff and sends the browser to the fixed Auth /sign/in or /sign/up surface.
   Temporary code URL is redacted from request logs, response is no-store/no-referrer, and Auth
   redeems atomically before a 303 to clean URL.
5. Auth starts the existing state machine only after handoff consumption. On success, Auth issues a
   purpose-specific opaque result code. Base redeems it once, applies sign-in/sign-up/step-up to the
   Base-owned identity/session/policy transaction, then resumes the pending OAuth authorization.
6. Base issues a high-entropy OAuth Authorization Code. Its Valkey payload binds client_id, exact
   redirect_uri, subject reference, Base Browser Session reference, S256 challenge/method, nonce,
   scope, auth_time, and client face.
7. RP GET /sign/in/callback loads the transaction cookie and checks version/face/state/nonce/expiry,
   then calls Base token endpoint with Authorization Code + code_verifier + private_key_jwt. Base
   validates client_id, exact redirect URI, PKCE, assertion and face against the issued payload
   before consumption (the current mismatch tests continue to see no token and an unconsumed code).
   It then performs one atomic `issued -> consumed` transition. Exactly one parallel exchange wins;
   a stale or duplicate browser cookie cannot create a second exchange. A consumed tombstone
   distinguishes replay from unknown/expired code and links only the resulting child RP
   Session/refresh family. No later failure restores a consumed code.
8. Base emits no token until the RP Session/refresh-family write and tombstone link succeed. A store
   or link failure rolls back or revokes the new child before responding. A detected replay denies
   exchange and revokes only the linked RP Session/refresh family under UMAXICA hardening; it never
   revokes the parent Base Browser Session or sibling RP Session. The RP validates token response,
   ID Token claims/signature/nonce, RFC 9068 Access JWT, and binding. Only then does it write local
   login state. The callback never retries automatically; the winning callback's cookie is not
   cleared or overwritten by a losing duplicate.

An RP Session revoke stops that session's future refresh/rotation and token issuance, but does not
retroactively invalidate an already-issued RFC 9068 Access JWT. Normal Access JWT authentication has
no RP Session row lookup; a valid JWT remains accepted through nominal `exp` plus the existing
30-second leeway. The current maximum nominal Access JWT lifetime is five minutes, bounded by parent
session expiry. Base Browser Session revoke revokes its children; Identity-wide revoke follows the
existing explicit identity policy. Sibling Base Browser Sessions are unaffected unless that policy
explicitly includes them.

The first-party IDs are core-app, core-com, core-org, side-app, side-com, side-org, and edit-org.
Their callback is exactly https://<registered-face-host>/sign/in/callback; post-logout URI exactly
https://<registered-face-host>/sign/out. Each has its own ES384 private key, public/JWKS
registration and client face. client_id and face mapping is static: app/client, com/visitor,
org/operator.

#### Base admission and Auth ceremony

1. Auth public /sign/in and /sign/up remain as entry URLs but only bridge to Base admission. Base is
   the only component that decides if a flow may begin. Org invitation is submitted through its
   existing invitation route and distinct policy branch.
2. Base creates or updates a purpose-specific, actor-partitioned handoff record with random 32-byte
   code digest, fixed route destination, face, admission context, created/expires/consumed times and
   safe return target. Expiry defaults to 60 seconds.
3. Auth accepts the code only for the expected host/face/purpose and uses one conditional transition
   to consume it. It atomically cancels the previous active flow, rotates/revokes the concrete
   face-specific `AuthCeremonySession`, starts a short-lived replacement with a new random-only
   cookie key, and redirects to a clean URL. This session is ceremony continuity only; it is not a
   Base login/session, Identity, policy, AAL, or RP authority and does not trigger Base
   introspection. Every new protected flow requires a fresh Base handoff.
4. Auth performs existing ceremony state transitions, then issues a new opaque result code in the
   matching purpose transaction. Its fixed payload reports only verified ceremony evidence that Base
   needs for its own decision. Auth does not assert or persist Base permissions or authoritative
   AAL.
5. Base redeems with an atomic conditional update. Only Base applies authority data, MFA/session
   policy and result. Replays, expired, cancelled, face mismatch, invalid state and DB errors reject
   closed. Codes are never placed in Inertia props/log attributes and URL-bearing endpoints set
   no-store/referrer controls.

The UI HTTP API stays same-origin under /api/v0. UI mutations keep Rails CSRF. External protocol
handoff routes are not UI APIs and require their own exact one-time-code, host, Origin/Fetch
Metadata and no-store contracts; they do not weaken ordinary CSRF protection.

#### Logout

- RP POST /sign/out performs only its local RP Session transition and launches Base OIDC
  end-session. RP does not directly revoke Base’s session. Base evaluates the validated ID Token
  hint / session binding, performs the already-authoritative logout behavior, and coordinates other
  RP backchannel/session cleanup as it does today.
- The transaction keeps ordered one-time challenge steps but removes the Auth/Sign RP hop.
  Core/Side/Edit flows become initiating RP cleared → Base authority cleared → finalized → exact
  initiating RP post_logout_redirect_uri. Base-local logout is Base authority cleared → finalized →
  Base /sign/out. Auth-local sign-out cancels the concrete AuthCeremonySession/ceremony state only,
  unless an explicit fixed link starts Base global sign-out.
- Successful local completion issues a five-minute SignOutNotice capability in P3's dedicated
  structured Valkey auth-state namespace. It is presentation-only, not proof of authority revocation
  or audit state. GET /sign/out requires no authenticated context, atomically consumes the
  actor/face- bound marker, sets no-store/no-cache/private and no-referrer, renders completion with
  clear_history: true, and returns 404 for missing, expired, consumed, authenticated, wrong-face,
  corrupt, or Valkey-unavailable markers. The only state it changes is this presentation marker; it
  never revokes or rotates identity/session/token/credential/logout authority or starts logout. No
  PostgreSQL notice tables are added; AcmeLogoutTransaction remains the durable logout/audit record.
- GET /sign/out/new remains a 303 to /sign/out/edit. GET /sign/out/edit only confirms. POST
  /sign/out executes/initiates. DELETE /sign/out cancels pending challenge/presentation only and
  returns to that surface’s Root; JSON behavior remains where already contractual. A
  completed/failed transaction cannot be revived.
- All browser registry values, transaction destinations and tests use exact /sign/out URIs; no
  arbitrary redirect parameter is introduced. The old browser /sign/out/complete is unroutable. Palm
  currently has no implemented browser logout; retain its native/API contract and remove the stale
  future /sign/out/complete example rather than creating a Palm route.

### Route and page migration map

| Current                                                 | Final contract                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Auth app/com/org /oidc/authorization and /oidc/callback | Retire as RP endpoints. Auth /sign/in and /sign/up stay as Base-admission bridges and ceremony entry URLs. Remove Auth /oidc/backchannel/logout because Auth is no longer a registered RP.                                                                                                     |
| Base app/com/org /oidc/authorization and /oidc/callback | Retire Base’s old RP start/callback only. Keep Base /oidc/logout as OIDC Authorization Server end-session; keep /oauth/authorize, token, JWKS, revocation, userinfo, discovery and global OIDC contracts.                                                                                      |
| Core/Side /oidc/authorization and /oidc/callback        | Replace with GET /sign/in and GET /sign/in/callback in Rails. Keep RP backchannel logout; do not implement any OIDC/PKCE/token exchange in TanStack Start.                                                                                                                                     |
| Edit org (currently no independent RP)                  | Add GET /sign/in, GET /sign/in/callback, RP backchannel logout and /sign/out under Edit::Org routes; change client ID to edit-org.                                                                                                                                                             |
| Seven clients’ redirect registration                    | Exact host + /sign/in/callback per distinct client. Exact post_logout_redirect_uri host + /sign/out. No wildcard or host synthesized from request.                                                                                                                                             |
| Auth UI /web/v0/*                                       | Move same-origin UI endpoints to /api/v0/*, preserving health/revision JSON endpoints, media types, Accept behavior, CSRF and no-store contracts. Delete old /web/v0 only after every source caller migrates.                                                                                  |
| Auth /edge/v0/token/check and /dbsc                     | Replace only Auth’s obsolete JWT-session behavior with concrete /api/v0 opaque-session operations, then retire old Auth routes/helpers after call-site/static contract search. Keep Base/Core token routes and refresh/DBSC contracts.                                                         |
| Auth/Base app/com/org GET /                             | Retain route as canonical Root; unauthenticated renders public Root at same host/path; authenticated renders current actor-specific Dashboard experience in Root controller/page without dashboard redirect. Remove RootSignInRedirect and RegionalRootRedirect use only from these six roots. |
| Auth/Base app/com/org /dashboard                        | Remove routes/controllers/pages/helpers/links/tests after Root takeover; no alias. Keep Core/Side/Edit dashboards.                                                                                                                                                                             |
| Base app/com/org /lobby                                 | Remove route/controller/page/helper and route Base post-logout to Base /sign/out.                                                                                                                                                                                                              |
| Auth/Base/Core/Side/Edit /sign/out/complete             | Replace with GET show at /sign/out. Remove nested completion route, generated helper, resolver and CompletionsController after all callers move.                                                                                                                                               |
| Browser termination paths                               | Common /sign/out show/new/edit/create/destroy; retain local route namespaces/helper style. Add destroy to Base/Core/Side/Edit where safe; Auth destroy remains ceremony cleanup.                                                                                                               |
| Edit Publishing routes                                  | Keep /publishing/{info,docs,news,help}/{app,com,org}/entries paths and named helpers. Replace route loops with twelve explicit resource declarations. No Base alias.                                                                                                                           |
| Edit operations                                         | Keep /revision, /health, liveness/readiness/startup and /api/v0/health.json + revision.json with current contracts.                                                                                                                                                                            |

Do not change Core/Side/Edit root semantics or retire their own dashboard routes as part of the
Auth/Base root change.

## Workstreams, dependencies, and TDD phases

Each implementation phase starts with failing characterization/contract tests, then a minimal
implementation, then schema/config migration if needed, then compatibility removal, then focused
verification. No test weakening, test-only production branches, skipped tests, or private-method
tests. Phases do not keep a legacy alias “just in case.”

| Phase                                                        | Depends on                                               | Tests first                                                                                                                                                                                                                                                                                                                                                  | Implementation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Migration/config                                                                                                                                                                                                                                                                             | Compatibility cleanup and exit                                                                                                                                                                                                                                       |
| ------------------------------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0: baseline and inventory (this plan)                       | None                                                     | Executed current bun run test and bin/rails test; reviewed route/ADR/source/test graphs.                                                                                                                                                                                                                                                                     | No implementation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | None.                                                                                                                                                                                                                                                                                        | Record database/debugger blockers. Complete; no source change.                                                                                                                                                                                                       |
| P1: authority and route contract lock                        | P0                                                       | Add contract tests for three actor faces, old/new OIDC clients, Auth direct entry denial, preserved global OAuth/JWKS, existing health and callback bindings, and exact registry matching. Add/adjust route inventory tests that fail on shared browser client IDs and deprecated browser paths.                                                             | Add architecture decisions defining Base physical authority, Auth ceremony boundary, seven RPs, allowed model boundaries, one-shot notice, root/sign-out contract. Choose explicit controller/route owners before data migration.                                                                                                                                                                                                                                                                          | No DB migration. ADR updates supersede authority/logout/Valkey docs after test contract is checked in.                                                                                                                                                                                       | Preserve Acme names as conceptual vocabulary; remove contradictory active statements but retain historical evidence as historical. Exit when one written authority/route map matches current target.                                                                 |
| P2: Browser Session/RP Session model                         | P1                                                       | Add hierarchy, one active child per parent+client, DB-enforced concurrent create, per-RP/parent/identity revoke, refresh reuse, admin permissions, and tests that ordinary Access JWT authentication performs no RP Session row query and remains valid through exp+30s after child revoke.                                                                  | Rename actor-specific Usage classes/tables/associations/services to RpSession. Update token issuer/revoker/session writer and Base Org admin UI. Remove RP Session active/JTI lookup from normal OIDC access authentication; keep the child row for refresh/new-issuance and administration. Add explicit revoke-RP-session and parent/identity revoke composition.                                                                                                                                        | Directly edit unshipped actor-ticket migrations and schemas; retain partial unique index under final names. Keep DB boundaries/no cross-DB FKs. Record five-minute Access JWT TTL and 30-second leeway in tests/docs.                                                                        | Remove TokenUsage aliases/tests/names; retain ClientToken/VisitorToken/OperatorToken as Base Browser Session roots. Exit with hierarchy, revoke scope, stateless JWT, and concurrency tests green.                                                                   |
| P3: Valkey topology and adapter                              | P1; independent of P2’s UI                               | Test purpose URL parsing, namespace isolation, fixed JSON schema, TTL, NX, atomic code CAS and notice consume, replay tombstones, adapter errors, hiredis selection, cleanup and no FLUSH. Real Valkey threads/processes prove one code winner, replay is distinguishable from unknown/expired, one notice winner, and store outage/corruption fails closed. | Add structured Valkey connection/namespace/error boundary and auth-state stores. Authorization codes use digest keys and Lua/CAS `issued -> consumed` tombstones, not GETDEL alone; retain a finite family-bound tombstone reference. SignOutNotice uses a separate digest-keyed five-minute presentation namespace with atomic GETDEL-equivalent consume. Centralize raw commands and preserve cache/rate-limit contracts.                                                                                | Consolidate development/test services/volumes to one Valkey with DB 0/1/2 dev and 3/4/5 test via responsibility URLs; add hiredis using locked redis-client API and verify actual driver. Namespaces include suite_run_id/worker_id/test_id, TTL, SCAN ensure-cleanup and surfaced failures. | Update Compose/.devcontainer/env/health/docs. No FLUSHALL/FLUSHDB and no notice tables. Exit only after real Valkey atomicity/concurrency and parallel cleanup tests pass.                                                                                           |
| P4: Base admission and Auth ceremony boundary                | P1, P2 for session references                            | Characterize state events, actor/surface differences, invitation, providers, step-up, settings, CSRF and current handoff/result. Add opaque handoff/result expiry/replay/CAS, direct-entry rejection, terminal irreversibility, session rotation and Auth-session non-authority tests.                                                                       | Base decides admission/step-up and issues purpose-specific opaque records. Auth uses concrete `ClientAuthCeremonySession`, `VisitorAuthCeremonySession`, and `OperatorAuthCeremonySession` with random-only `__Host-auth_sid`; session is short-lived ceremony continuity only, has no Base login/identity/AAL/policy/RP authority, and each protected new flow needs Base admission. Keep existing state machines and provider contracts; replace internal JWT results with opaque Base-consumed results. | Add/edit actor-purpose migrations only where existing transaction ownership is proven; digest fields, TTL/indexes, CAS state. No generic flow/session/result table.                                                                                                                          | Remove direct Auth starts and JWT session requirements after callers migrate; keep Jump JWKS and audit Auth edge callers. Exit with provider/flow/CSRF and authority-boundary tests green.                                                                           |
| P5: Valkey OAuth codes and seven RP clients                  | P2, P3, P4                                               | Add pure-library PKCE/claim/redirect tests, seven separation tests, assertion failure/replay tests, Valkey code tombstone/replay/failure tests, and duplicate callback/two-tab tests proving one token exchange and one local login write. Assert no RP Session lookup on normal Access JWT path and no token for mismatch/corrupt/outage.                   | Build pure OIDC RP values and thin adapters. Register seven independent ES384 clients and exact per-host `/sign/in/callback`/`/sign/out`; implement Rails callbacks. Change exchange coordinator to code CAS/tombstone and link the child family only after successful grant; on replay revoke only linked child family. Keep PostgreSQL JTI and RFC 9068/refresh/backchannel contracts.                                                                                                                   | Remove old AuthorizationCode models/tables after store tests; require AUTH_STATE_REDIS_URL and per-client key namespaces.                                                                                                                                                                    | Remove old shared browser registrations/callbacks only after seven flows pass; retain native/content and Base authority endpoints.                                                                                                                                   |
| P6: Auth/Base canonical Root                                 | P4 for ceremony-session boundary and P2 for session data | Add six-root tests for public 200, local Sign In, flash transport, no auto-start, `ri`, private/no-store cache, and `/dashboard` unroutable. Base authenticated branch tests FullAccess/selected actor/restricted/verification/Action Policy. Auth Root remains public with a ceremony cookie and never exposes Base-login or Dashboard authority.           | Remove six Root redirects. Base Root explicitly preserves former Dashboard authorization/content; Auth Root is minimal public ceremony entry and old Auth Dashboards are retired. No Auth ceremony cookie is used as authentication proof.                                                                                                                                                                                                                                                                 | No schema beyond P4; no new flash writes.                                                                                                                                                                                                                                                    | Retire redirect concerns only on six roots, remove six dashboards and Base lobby, retain Core/Side/Edit dashboards and region normalization.                                                                                                                         |
| P7: common browser sign-out resource and one-shot completion | P2, P3, P5, P6                                           | Add route/request tests for show/new/edit/create/destroy; one-shot Valkey notice success/missing/expired/authenticated/replay/parallel consume; GET no authority mutation; clear_history; stale cancellation CAS; OIDC exact URI/cross-host/fetch/origin/challenge/backchannel.                                                                              | Align route semantics and shorten Auth-as-RP logout hop. Use P3’s dedicated five-minute Valkey notice marker, not PostgreSQL tables; only marker consumption mutates on GET. Preserve Base authority/logout transaction and Auth ceremony cleanup.                                                                                                                                                                                                                                                         | No notice migration. Update exact `/sign/out` registrations and all coordinator targets. P7 explicitly depends on P3’s Valkey adapter.                                                                                                                                                       | Delete completion routes/controllers/pages/helpers and `/lobby`; supersede contradictory ADRs; preserve Palm native behavior. Exit with one-shot/race/security suite green.                                                                                          |
| P8: Edit Publishing boundary closure                         | P1 and P5; P5 owns Edit’s independent OIDC RP wiring     | Verify host isolation, exact Edit callback, independent edit-org registration, all 12 matrix and lifecycle tests, operator Active/Action Policy, standard health/revision contracts and current public publishing API. Add failure assertion for dynamic route loops through route inventory.                                                                | Keep the Edit RP routes/controller and edit-org registration wired in P5. Replace only the Publishing route-generation loop with 12 explicit route declarations. Keep app/controllers/edit/org/publishing and src/pages/edit/org/publishing ownership. Keep only necessary current Edit controller guards; do not copy the whole Base graph or add a broad Concern.                                                                                                                                        | No Publishing schema migration; host config is already present. Update host/env examples only where the existing source of truth lacks an Edit value.                                                                                                                                        | Ensure Base.Org has no duplicate management route/page/controller. Keep public /api/v0/entries and all Publishing data/models in Global. Update security/public-entrypoint inventories. Exit with 12 cells and existing Publishing tests green.                      |
| P9: docs, full regression, evidence                          | P1–P8                                                    | Run exact targeted suites listed below, then full Rails, coverage, JS CI, browser-history tests. Add tests to current route/security inventories instead of weakening them.                                                                                                                                                                                  | Fix only regressions in changed workstreams. No new architecture after phase acceptance.                                                                                                                                                                                                                                                                                                                                                                                                                   | Validate final DB schemas and six-DB config; bin/rails db:prepare on test/dev target. No production database migration.                                                                                                                                                                      | Update ADR status, logout/root/identity/OIDC/Valkey/API/Edit docs. Write a flat evidence/2026-<run-date>-auth-boundary-consolidation.md only after checks have run; include exact command results and any blocker. Exit only when acceptance criteria below are met. |

#### Mandatory corrections to the phase table

The following clarifications are normative for the rows above and resolve the single-use and
authority-boundary corrections without changing the P0–P9 dependency order:

- P2 must remove the current `OidcAccessTokenAuthenticator` dependency on an active Usage/RP Session
  row from ordinary JWT authentication. It may retain only the identity/resource reads required to
  materialize a response. RP Session revocation therefore stops refresh and new issuance, leaves
  sibling sessions active, and does not invalidate an already-issued JWT before its five-minute
  nominal expiry plus the existing 30-second leeway.
- P3's Authorization Code store is a digest-keyed fixed-schema Valkey store with TTL and an atomic
  `issued -> consumed` CAS/tombstone. GETDEL alone is insufficient because replay must be
  observable. The successful tombstone retains only consumed time, public client/RP face and the
  minimal linked RP Session/refresh-family reference; it expires no later than the live
  family/parent lifetime and is not an audit record. Validation mismatch before CAS issues no token
  and preserves the current unconsumed-code contract; after CAS, no failure restores the code. P3's
  SignOutNotice marker is a separate five-minute Valkey namespace and may use atomic
  GETDEL-equivalent consume; no notice tables are added.
- P4's `__Host-auth_sid` records are named `ClientAuthCeremonySession`,
  `VisitorAuthCeremonySession`, and `OperatorAuthCeremonySession` (subject to exact repository
  naming verification), and are ceremony-local only. They contain no roles, permissions, policy,
  AAL, Base-login proof, or RP authority. A session alone cannot start a protected flow; Base
  admission is required, and new admission atomically cancels/rotates old ceremony state.
- P5 treats encrypted RP transaction-cookie deletion as cleanup, not exactly-once enforcement. Base
  Code CAS and callback-write atomicity enforce one exchange and one persistent local login under
  duplicate callbacks/two tabs/stale cookies.
- P6's authenticated former-Dashboard behavior applies to Base Roots. Auth Roots remain public
  ceremony-service entries regardless of a local ceremony cookie; the cookie cannot prove Base login
  or authorize a user-specific Dashboard. The Auth Dashboard is retired to preserve the authority
  boundary.
- P7 depends explicitly on P3 for its Valkey presentation marker. GET `/sign/out` changes no
  Identity, Base Browser Session, RP Session, token, credential, or logout-authority state; only the
  one-shot presentation capability is consumed.

### Required tests by regression boundary

**Base/Auth admission and ceremony**

- Base handoff: 256-bit entropy contract, digest-only storage, 60-second expiry, atomic single
  redemption, cancel/revoke/expiry/face/destination mismatch, duplicate concurrent redeem exactly
  one winner, no raw code in URL logs/error logs/props.
- Auth direct /sign/in, /sign/up, /verification or generic step-up without valid Base admission
  cannot enter a ceremony. Each one-time result succeeds once, expires, rejects replay and fails
  closed if the authority DB is unavailable.
- SignIn/SignUp actor state machine behavior for success, all current guardrails/checkpoints,
  terminal failures, cancellation and compensation. Preserve App/Com/Org differences and Org
  invitation path.
- One StepUp rail with passkey/TOTP/email OTP branches only where currently supported; concurrent
  method verifications cannot both succeed; terminal cannot be revived.
- Secret Credential settings route ownership in Base, while Auth Secret Credential authentication
  remains. Google/Apple/Entra callbacks preserve exact URL/provider state/link/unlink/step-up
  requirements.
- __Host-auth_sid random-only, host-only cookie attrs; invalid/revoked/expired row denied; session
  rotation cancels prior active flow; API mutating calls fail without Rails CSRF token.
- No bearer/access/refresh/ID/assertion/handoff/result/cookie secret in Inertia props, logs,
  exception text or metric labels.
- Keep Auth .well-known/jwks.json and Jump contract tests.

**OIDC/RP/Valkey**

- Seven unique IDs/faces/key namespaces; exact allowed redirect URI; wrong host/client/face
  rejection; unknown RP fail closed.
- PKCE S256 only; fresh state/nonce/verifier per request; invalid state, nonce, code_verifier,
  expired cookie, cross-face cookie and malformed cookie reject; at most four active transactions;
  cookie attributes; same-origin return_to and open-redirect negatives.
- private_key_jwt alg/kid/signature/iss/sub/aud/iat/exp/jti/typ failures, wrong exact audience,
  UMAXICA's 60-second maximum assertion lifetime (not an RFC requirement), existing 30-second
  clock-leeway behavior, PostgreSQL JTI replay including concurrent insert and DB unavailable.
- Base token endpoint retains its current back-channel/null-session boundary: missing protocol
  context yields a deterministic OAuth error and never issues tokens.
- Authorization code wrong client_id, redirect_uri, verifier, face, replay, parallel reuse, corrupt
  JSON/schema, Valkey unavailable, TTL expiry. Only one parallel consume succeeds; replay is
  distinguishable from unknown/expired; no token is issued on any storage/assertion failure. A
  consumed-but-later-invalid code remains consumed, and a replay revokes only its linked child
  refresh family under local hardening.
- Callback does not write an RP Session/cookie before all token, ID Token, Access JWT, face/session
  binding checks pass; encrypted transaction-cookie deletion is cleanup only; duplicate callbacks
  cannot create multiple persistent login states and there is no token-exchange retry.
- Normal whoami/access authentication stays RFC 9068 JWT validation and does not query RP Session
  per request; a session database outage does not invalidate that cryptographic path. Refresh family
  rotation, backchannel logout and per-client session binding remain covered. Tests assert sibling
  RP Sessions remain active after a child revoke and an already-issued JWT remains valid through exp
  plus the existing leeway.
- Structured access static guard confines RedisClient/raw command usage to lib/umaxica/valkey and
  the designated Auth State store. No Marshal, FLUSHALL, FLUSHDB or unbounded arbitrary hash.
- Valkey tests use suite_run_id + worker_id + test_id namespaces, TTL, own-prefix SCAN cleanup in
  ensure, no silent cleanup failures, no cross-worker delete. Run real Valkey
  contract/atomicity/concurrency tests at PARALLEL_WORKERS=4.
- Hiredis contract reports the actual driver selected through the documented locked-version API.

**Root, logout, and Edit**

- Six Auth/Base Root public/authenticated representations, local Sign In href, same URL,
  actor-specific authorization, restricted and selected actor behavior, no shared caching,
  valid/missing/invalid ri normalization. /dashboard and Base /lobby are unroutable, while
  Core/Side/Edit dashboards stay.
- Browser logout show/new/edit/create/destroy route contract on Auth/Base/Core/Side/Edit faces that
  exist. One-shot success is 303 → first GET /sign/out → render/clear Inertia history → consume.
  Missing, expired, authenticated, wrong-face, concurrent loser and replay are 404. Completion GET
  changes no Base session, RP session, credential, refresh family, or logout transaction.
- Destroy cancels only pending logout state; it does not log out; stale cancel after terminal cannot
  change state. New/authenticated requests cannot bypass Base auth. post_logout_redirect_uri remains
  exact and realm-bound. Cross-host challenge is one-use, step-checked and protected by current
  Origin/Fetch Metadata checks.
- Rails route test proves Core /sign/in and callback reach Rails rather than TanStack. Old
  /sign/out/complete unrouteable on browser surfaces. OIDC authority end-session round trip ends at
  exact /sign/out.
- Preserve Inertia clear_history and encrypt_history behavior; run existing Playwright/e2e harness
  for browser back/reload if its runtime is available.
- Edit host isolation and Host Authorization, all twelve Publishing cells,
  list/show/new/create/edit/update/publication/archive lifecycle, optimistic locking, revisions,
  operator active/restricted and Action Policy, Inertia names/props. Health
  liveness/readiness/startup/summary, revision and JSON APIs preserve status/media/Accept/cache
  behavior. Keep all Publishing model/query/operation tests green.

### Verification commands

These commands exist in the current checkout or are the current CI job commands. Run targeted tests
before broad checks; the whole Rails test suite requires the configured PostgreSQL service.

**Focused Rails contracts**

- bin/rails test test/controllers/auth/app/roots_controller_test.rb
  test/controllers/auth/com/roots_controller_test.rb
  test/controllers/auth/org/roots_controller_test.rb
  test/controllers/base/app/roots_controller_test.rb
  test/controllers/base/com/roots_controller_test.rb
  test/controllers/base/org/roots_controller_test.rb
- bin/rails test test/controllers/concerns/sign_out_notice_test.rb
  test/controllers/concerns/sign_out_inertia_pages_test.rb
  test/controllers/concerns/sign_oidc_logout_completion_test.rb
  test/services/acme_logout_transaction_coordinator_test.rb
  test/controllers/base/app/oidc/logouts_controller_test.rb
- bin/rails test test/services/oidc/client_registry_test.rb
  test/integration/sign_app_oidc_browser_flow_test.rb
  test/controllers/base/oauth_oidc_authority_test.rb
- bin/rails test test/models/oidc_token_usage_test.rb
  test/services/oidc/token_exchange_service_test.rb
  test/services/oidc_access_token_authenticator_coverage_test.rb
  test/services/oidc_refresh_token_issuer_surface_test.rb
- bin/rails test test/controllers/edit/org/publishing/management_matrix_test.rb
  test/controllers/edit/org/publishing/entries_controller_test.rb
  test/controllers/edit/org/publishing/entry_publications_controller_test.rb
  test/controllers/edit/org/publishing/entry_archives_controller_test.rb
  test/integration/routes/edit_org_publishing_management_route_contract_test.rb
  test/integration/health_revision_contract_test.rb
- bin/rails test test/config/host_authorization_contract_test.rb
  test/integration/routes/legacy_api_namespace_guard_test.rb
  test/contracts/openapi_route_coverage_test.rb test/unit/security/action_policy_usage_test.rb
  test/unit/security/ri_routing_contract_test.rb
- Add new tests adjacent to these files for handoff/result, PKCE library, Valkey adapter/atomicity,
  route deletion, Auth /api/v0 and 7-client separation.

**Project checks**

- bin/rails routes, then inspect route output for all seven RP hosts and absence of Auth RP, six
  retired /dashboard paths, Base /lobby, and browser /sign/out/complete.
- bin/rails db:prepare on the configured test/dev databases after the final unshipped migration
  shape.
- bin/rails test for the full Rails suite.
- COVERAGE=true bin/rails test test/ for the CI coverage run. Preserve .simplecov floors: 97% line,
  70% per file, 95% models/policies, 90% values/services, 99% model/policy/value groups, 98%
  service/controller groups, max line drop 0.2 points, 90% branch with max drop 0.5, 95% method. Do
  not lower any threshold.
- bundle exec rubocop --fail-fast --format github and bundle exec erb_lint --lint-all.
- bun run test, bun run test:coverage, bun run format:check, bun run lint, bun run typecheck, bun
  run openapi:lint, bun run openapi:verify, bun run build. bun run ci is the JavaScript
  check/coverage/build aggregation, not a full Ruby CI entrypoint.
- bun run test:e2e for existing Inertia/Playwright history and logout coverage when browser services
  can run.
- There is no bin/ci file in the current checkout. The combined canonical Ruby/JS coverage of CI is
  the jobs in .github/workflows/ci.yml. Run the same commands above; do not report bun run ci as a
  complete Rails CI pass.
- If the configured security scanner is present in the current workflow, run its current invocation;
  otherwise use the repository’s security invariant tests and static boundary checks. Do not invent
  a scanner command.

### Risk register

| Risk                                                      | Likelihood / impact  | Mitigation and rollback                                                                                                                                                                                                                                                                                                                         |
| --------------------------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Passkey RP ID/origin breakage                             | Medium / very high   | Keep Auth host, WebAuthn RP ID, and origins unchanged. Add browser-level registration/assertion contracts before Auth OIDC cleanup. Do not repoint Passkey callbacks to Edit. Roll back only the affected route integration, not RP design.                                                                                                     |
| Google/Apple/Entra callback breakage                      | Medium / high        | Treat provider console URI and callback paths as immutable. Test state binding, failure route and link/unlink before moving settings. Preserve Apple notifications and Org-only Entra.                                                                                                                                                          |
| Shared client ID/key/session survives accidentally        | High / very high     | Static registry test requires seven unique client IDs and seven signing namespaces, exact host callback, unique face. Add static tests against shared browser registrations after all seven routes work.                                                                                                                                        |
| OIDC authorization-code race/replay                       | Medium / very high   | Use digest-keyed Valkey Lua/CAS `issued -> consumed` tombstones with TTL, exactly-one-winner thread/process tests, replay-vs-unknown assertions, and no raw code. Link only the child RP Session/family; on replay revoke that family under local hardening. Fail closed on store/corrupt-schema errors; do not ship without real Valkey tests. |
| private_key_jwt replay or availability regression         | Low / very high      | Keep PostgreSQL unique JTI persistence and failure closed; test parallel JTI insert and PG unavailable. Remove exception message content from logs.                                                                                                                                                                                             |
| Browser transaction cookie collision or leak              | Medium / high        | Unique cookie per transaction, max four, five-minute TTL, host-only encrypted cookie, face validation, safe return_to; test two tabs, expiry, malformed data, clean callback redirect.                                                                                                                                                          |
| Base/Auth admission loop or stale flow cookie             | Medium / high        | Purpose-specific handoffs, fixed routes, one-use result, clean 303, new flow cancels old. Test direct-entry rejection, expired/replayed handoff, and same-browser overlap.                                                                                                                                                                      |
| RP session revoke becomes global                          | Medium / very high   | Separate RpSession revoke service from Base Browser Session revoke and OIDC end-session. Add sibling-active assertions in DB and controller tests. Keep normal Access JWT request path DB-free.                                                                                                                                                 |
| Session root hard cascade deletes erase audit state       | Medium / high        | Replace delete-all child behavior with explicit child revoke where history/admin state is required. Verify actual callbacks and current retention rules before altering parent lifecycle.                                                                                                                                                       |
| Root dashboard loses inherited guard                      | Medium / very high   | Base Root authenticated branch must preserve FullAccess selected actor, authentication, restricted session, verification, access policy and explicit Action Policy. Test app/client, com/visitor, org/operator and restricted contexts separately.                                                                                              |
| Root cache leaks actor data                               | Low / very high      | Set private/no-store on all six Root variants unless the established policy proves equally strong. Test both authenticated and public response headers.                                                                                                                                                                                         |
| Auth ceremony session becomes a second login authority    | Medium / very high   | Concrete actor-specific short-lived `AuthCeremonySession` stores only a digest of the random `__Host-auth_sid` key and lifecycle fields. No Base login, Identity, AAL, permissions, policy or RP authority; no Base introspection. Require fresh Base admission for every protected flow and make Auth Root public.                             |
| One-shot completion race                                  | Medium / high        | Keep CookieStore for transport but use a dedicated five-minute Valkey presentation namespace with digest key and atomic consume; parallel requests yield exactly one render. GET changes only this marker. Valkey outage/corruption yields 404 and no authority mutation; no PostgreSQL notice tables.                                          |
| Duplicate RP callback creates multiple login states       | Medium / high        | Treat encrypted transaction-cookie deletion as cleanup only. Base Authorization Code CAS/tombstone permits one exchange; callback persistent login write is conditional/idempotent and losing stale-cookie callbacks cannot overwrite the winner.                                                                                               |
| Access JWT remains valid after RP revoke                  | Medium / high        | Make the residual bound explicit: nominal five-minute RFC 9068 JWT plus 30-second configured leeway; no per-request RP Session lookup or hidden blacklist. Test refresh/new issuance denial, sibling activity and normal JWT acceptance through that bound.                                                                                     |
| Logout challenge step drift / redirect loop               | Medium / very high   | Update ordered state sequence with contract tests before route cleanup. Retain exact URL allowlisting, origin/fetch metadata, challenge one-use, cancel only pending. Exercise app/com/org and Core/Side/Edit chains.                                                                                                                           |
| Back button restores privileged Inertia history           | Medium / high        | Preserve clear_history: true at new show page with global encrypt_history. Test browser navigation after logout.                                                                                                                                                                                                                                |
| Old /dashboard, /lobby, /sign/out/complete links remain   | Medium / medium      | Search all source/tests/docs and route inventories; test retired routes are unroutable and no helper remains. Do not retain aliases.                                                                                                                                                                                                            |
| Edit Authorization or Publishing changes accidentally     | Low / high           | Keep operator/Action Policy and current Publishing DB/query/model tests; only alter Edit’s RP client/routes and explicit route declarations. Preserve public API.                                                                                                                                                                               |
| Future Publishing extraction becomes harder               | Low / high           | No cross-DB FK/association/transaction; no Base controller dependency in Publishing models/operations/policies; retain stable operator ID provenance.                                                                                                                                                                                           |
| One Valkey service blurs isolation or drops nonprod state | Medium / high        | Document logical DBs are not security boundaries; keep URL responsibilities, ACL/credentials where supported, namespacing/TTL. Reuse one dev/test volume; cache/rate-limit contents may be lost on local recreation, no production topology change.                                                                                             |
| CI cannot distinguish baseline from regression            | High until env fixed | Fix only test service/socket prerequisites, rerun full baseline before code, save evidence and compare later full run. Do not claim individual baseline Ruby failures from a suite that never started.                                                                                                                                          |

### Migration, compatibility, and rollback

- The user-provided premise is that the architecture and schema are unshipped. Use direct
  edits/removal of unshipped migrations, regenerate the actor ticket schemas, remove old
  AuthorizationCode/TokenUsage models/tests/routes/config and do not add deprecated aliases, dual
  writes, or redirect shims.
- Preserve all current Publishing schema and data semantics. The Publishing database remains in
  Global Rails.
- Recreate only local development/test databases after confirming their connection URLs. No
  production/shared database command is in scope.
- Update env examples and BootConfig/Host Authorization with required one-argument ENV.fetch
  settings. Do not add silent defaults for production secrets or client keys.
- Old RP client IDs and old browser session cookies are intentionally invalid after the unshipped
  cutover. New RPs start fresh; no dual client registrations. Native/content OIDC client
  registrations remain.
- Keep production cache/rate-limit responsibility URLs separately configured. The one Valkey
  service/six DB layout applies only to development/test. Do not treat logical database number as a
  security boundary.
- No push, PR, deployment, or migration against a deployed database. Before deployment, the final
  complete test/coverage/security gate must pass. A local rollback before deployment is source
  revert plus local DB recreate; there is no runtime compatibility migration to preserve old local
  rows.
- If a required route/host/CI test cannot run because its external service is unavailable, record
  the exact blocker in the implementation evidence and do not mark completion.

## Documentation and ADR work

Implementation must create or amend concise authoritative material, then remove contradictory active
claims:

1. Add an ADR for Base as the sole physical authority surface, Auth as ceremony service, the seven
   independent first-party RPs, opaque handoff/result, Base session hierarchy and Auth session
   boundary. Amend/supersede adr/acme-sign-core-base-port-boundary.md and
   adr/sign-residual-idp-surface-retirement.md where they call Base an RP or Auth/Sign a special RP.
   Preserve Acme conceptual naming and non-OIDC Jump JWKS facts.
2. Add a Valkey ADR for responsibility URLs, one dev/test service/six logical DBs, structured
   access, hiredis driver verification, auth-state fail-closed behavior and per-test namespace/TTL
   cleanup. Mark adr/valkey-cache-and-rate-limit-stores.md and
   adr/solid-cache-removal-and-valkey-cache-separation.md superseded for the service topology, not
   for Solid Queue or existing cache/rate-limit semantics.
3. Amend/supersede adr/logout-ceremony-boundary.md and adr/base-lobby-unauthenticated-entry.md;
   update docs/security/logout-sequence.md with Root home, one-shot /sign/out show, allowed
   presentation-only GET mutation, no authoritative GET mutation, shortened logout steps, exact
   post_logout_redirect_uri and Palm scope.
4. Update docs/identity/authority-boundary.md, docs/security/session-token-authority.md,
   docs/security/step-up-ceremony-delegation.md, docs/security/social-callback-boundary.md,
   docs/security/sign-in-sequence.md, docs/security/sign-up-sequence.md,
   docs/security/public-entrypoints.md, docs/vendor/identity/01_responsibility_matrix.md,
   docs/vendor/identity/03_route-endpoint-inventory.md,
   docs/vendor/identity/04_cookie-session-token-matrix.md,
   docs/vendor/identity/11_decision-register.md, docs/vendor/identity/12_gap-risk-register.md,
   docs/vendor/identity/13_normative-baseline.md, docs/reference/api-design-standards.md,
   docs/architecture/regional-content.md, docs/operations/core-nextjs-zero-cookie-edge-contract.md,
   and the current sign-in/up/session diagrams. `docs/auth-ceremony/CONTEXT.md`,
   `docs/auth-ceremony/AUTHORITY-MATRIX.md`, and the old audit-ledger plan are absent from the
   current checkout; do not refer implementation work to them or recreate them.
5. Update docs/architecture/publishing-persistence.md and Edit security/health/revision inventories
   to say Edit owns staff Publishing UI, Base no longer owns it, Publishing DB remains in Global,
   current org/operator authentication remains Action Policy protected, Edit’s independent RP ID and
   health/revision contract.
6. Update .env examples, Compose/Dev Container docs and health/runbook material for the one nonprod
   Valkey service. Keep records of checks in flat evidence/ files only after execution.

## Open questions

No target architecture choice remains open: the user’s specified target takes precedence over
current code and the active ADR statements are to be superseded where they conflict. Two
implementation facts still require verification at the beginning of their owning phase, but do not
block plan approval:

1. Confirm the exact table/connection owner for every Auth actor ceremony result before choosing its
   digest columns. The current actor-specific flows and ticket databases are identified; test
   characterization must prove which existing transaction owns each result before adding a field or
   a dedicated same-purpose table.
2. Confirm how to make the current Ruby debugger stop binding its Unix socket in the managed test
   environment and restore PostgreSQL hostname primary. This is required to establish the test
   baseline and run Rails checks, not a product-design question.

## Security invariants required for completion

- **AUTHORITY-1:** Auth may execute credential ceremonies, but cannot independently grant an
  Identity, Base Browser Session, RP Session, authorization policy decision, or authoritative AAL.
- **AUTHORITY-2:** An Auth ceremony-session cookie alone cannot start a protected new ceremony; a
  current Base admission/handoff is required. Stale Auth state after Base revoke grants nothing.
- **TOKEN-1:** Normal Access JWT validation and RP Session revocation lookup are separate. The
  normal request path does not query the RP Session row, and a session-database outage does not
  change cryptographic JWT validation.
- **TOKEN-2:** RP Session revoke stops that session's future refresh, rotation and token issuance,
  leaves sibling RP Sessions active, and does not retroactively change an already-issued JWT's
  validity. Existing nominal five-minute JWTs remain valid until expiry plus the configured
  30-second leeway. Parent Browser Session revoke revokes its children; Identity-wide revoke follows
  explicit identity policy.
- **OIDC-1:** Every Authorization Code has exactly one successful atomic consumption; a finite
  digest-keyed tombstone distinguishes replay from unknown/expired code.
- **OIDC-2:** Duplicate/replayed callbacks cannot create more than one persistent local RP login
  state, even when an encrypted browser transaction cookie is sent twice.
- **OIDC-3:** Client, face, redirect URI, PKCE, assertion or payload mismatch produces zero token
  issuance. Storage failure or corrupt schema is fail closed; a post-consume failure never restores
  the code.
- **LOGOUT-1:** GET `/sign/out` never changes Identity, Base Browser Session, RP Session, token,
  credential, or logout-authority state.
- **LOGOUT-2:** The only server-side state GET `/sign/out` may change is atomic consumption of its
  one-shot presentation capability (plus non-authoritative browser-marker cleanup).
- **SESSION-1:** Identity → Base Browser Session → RP Session revoke scopes are explicitly separate
  and tested.
- **SESSION-2:** Revoking RP A does not revoke sibling RP B.
- **STORAGE-1:** Valkey failure, timeout, corrupt payload, or schema mismatch never fails open to
  authentication or token issuance.
- **STORAGE-2:** Tests never call `FLUSHALL` or `FLUSHDB`; cleanup is prefix-scoped, ensured, and
  bounded by TTL.
- **SECRET-1:** Raw authorization/handoff/result codes, refresh/access/ID tokens, assertion JWTs,
  private keys, encrypted transaction cookies and session IDs never appear in logs, metrics,
  exceptions, or Inertia props.

## Completion conditions

Implementation is complete only when all of the following hold:

- Base is the only OIDC IdP/Authorization Server surface; global OAuth/OIDC, discovery, token,
  refresh, revocation, userinfo, RFC 9068 Access JWT, ES384 and Base end-session remain operational.
- Auth has no RP authorization/callback/backchannel state, token exchange, RP session, or shared
  sign-rp client; it retains the approved ceremony/provider/settings responsibilities and Jump JWKS.
- Core app/com/org, Side app/com/org and Edit org each work as their own client with unique key,
  exact /sign/in/callback and /sign/out, PKCE S256, private_key_jwt, per-RP transaction cookie and
  RP Session.
- Core Rails owns /sign/in and /sign/in/callback despite the TanStack catch-all.
- Base→Auth handoff and Auth→Base results are opaque, high entropy, digest-only, short-lived,
  single-use and atomic. Base admission/policy is authoritative.
- Auth __Host-auth_sid is random-only and server-side; concrete AuthCeremonySession rows are
  short-lived continuity records, never Base login/identity/AAL/policy/RP authority; no
  generic/polymorphic auth flow/session table exists; concurrent transitions cannot both succeed and
  terminal state cannot be revived.
- Identity → Base Browser Session → actor-specific RP Session exists; DB uniqueness enforces one
  active RP Session per parent+client. Identity/base/RP revocation boundaries are independently
  tested; no per-request RP session lookup was added.
- TokenUsage is fully removed from active models/routes/tests/docs; Access JWT remains a separate
  short-lived RFC 9068 token with its five-minute nominal TTL and 30-second leeway. Normal request
  authentication performs no RP Session lookup; child revoke stops future refresh/issuance only.
- One Valkey dev/test service, six logical DBs, structured adapter, required AUTH_STATE_REDIS_URL,
  actual hiredis driver, atomic code CAS/tombstone replay handling, five-minute presentation-marker
  namespace and parallel cleanup are verified. No test FLUSH calls remain.
- All listed negative security contracts pass; failures fail closed and no secret appears in
  logs/errors/metrics/Inertia.
- Base's three authenticated Roots preserve the former Dashboard authorization/content chain; Auth's
  three Roots remain minimal public ceremony entries even with `__Host-auth_sid`. All six Roots meet
  public behavior/cache policy; six /dashboard and Base /lobby are unroutable.
- Browser /sign/out shape is consistent, its one-shot show has exactly one successful consume and
  clear_history, /sign/out/complete is unroutable, and OIDC/logout races/security/exact redirect
  tests pass. Auth show represents local ceremony cleanup only.
- Edit host and health/revision endpoints remain standard; the 12 Publishing routes are explicit,
  the Publishing lifecycle works only on Edit, Base has no duplicate management UI, and Publishing
  persistence/API remains unchanged.
- All active ADR/docs/routes/inventories match the final implementation. Evidence describes only
  executed checks.
- Focused Rails and UI suites, full Rails suite, configured coverage gates, Ruby/ERB lint,
  JavaScript lint/format/type/OpenAPI/tests/build, and relevant browser tests pass. No new failing
  test is marked pre-existing.

## Implementation start status

The plan is ready to hand to an implementation session. Start only after restoring the test
PostgreSQL/debugger prerequisites and capture a runnable full Rails baseline. Execute P1 first and
use each phase’s listed failing tests before implementation.
