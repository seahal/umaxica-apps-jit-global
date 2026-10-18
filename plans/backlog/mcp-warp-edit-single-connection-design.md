# MCP Warp/Edit Single Active Connection Direction

## 1. Status

**Status: BACKLOG — DISCUSSION PENDING — NOT APPROVED FOR IMPLEMENTATION**

Recorded on 2026-10-10. Product direction below is the user's confirmed direction for future
review, not an approved technical design. Implementation has not started for this proposal.
This document does not supersede accepted ADRs or authorize restoring any endpoint.

## 2. Purpose

Preserve the product decisions and identify questions for a future MCP design review, following
[Plans](../README.md). Distinguish **confirmed direction**, **observed implementation**, and
**open design questions**. Any implementation mechanisms mentioned are candidates only.

The local `seahal/umaxica-apps-jit-global` worktree on branch `feature` was inspected at HEAD
`651b4575746fef7346f46c37ad68eed433b58e96`. It already contained unrelated staged/unstaged or
untracked work; observations below describe local files, not a clean checkout or deployed service.
Local sources take precedence over potentially delayed GitHub content. No matching single-connection
MCP backlog was found; the existing integrated Warp plan discusses naming, not this product rule.
The edge repository was not needed to establish the Rails facts and was not inspected. Core's
TanStack implementation and deployed edge routing remain unverified here.

## 3. Confirmed Product Direction

- Support only the new official MCP specification. The user-selected current baseline is
  **2026-07-28**. Recheck the latest official specification before implementation. Provide no
  legacy protocol compatibility, downgrade, or fallback.
- Limit public MCP entry points to Warp and Edit in the four slots below. Core, including its
  TanStack web application responsibilities, is outside MCP scope. Base has no MCP entry point
  and is not an MCP Resource Server. Palm is not an additional MCP entry point.
- Acme is the sole conceptual Identity Provider / OAuth Authorization Server. Use standard
  OAuth/OIDC and existing identity infrastructure; create no independent MCP authentication system.
  Resolve its physical mapping against current ADRs before implementation.
- Restrict Access Tokens to the intended Resource Server. Verify the Identity-to-Account
  relationship and current authorization, reusing Rails Action Policy and established domain
  authorization wherever applicable. Preserve TLD and surface boundaries.
- Allow at most one active OAuth connection authorization per Account per MCP connection slot.
  A successfully established new authorization automatically revokes the previous authorization
  in that same slot. Token renewal is not a new connection.
- Base will provide authenticated connection administration and auditing for persistent OAuth
  connection authorizations, separately from MCP protocol or transport sessions.
- Security takes priority. Convenience does not justify omitting authorization checks.

| Audience surface | Warp | Edit |
| --- | --- | --- |
| app | One active connection authorization per Account | Out of scope |
| com | One active connection authorization per Account | Out of scope |
| org | One active connection authorization per Account | One independently active connection authorization per Account |

## 4. Current Implementation Evidence

These are source observations, not results of running Rails or MCP clients.

### Routes, hosts, and existing features

| Area | Local evidence and limits |
| --- | --- |
| Warp | [Routes](../../config/routes/warp.rb) contain app/com/org namespaces, host constraints, roots, dashboards, settings, browser sign-in and OIDC callbacks. Host selectors are `warp_service`, `warp_corporate`, and `warp_staff`; local aliases are `warp.app.localhost`, `warp.com.localhost`, and `warp.org.localhost`. [Route contract tests](../../test/integration/routes/warp_route_contract_test.rb) name `www-jp.umaxica.app`, `www-jp.umaxica.com`, and `www-jp.umaxica.org`. These are repository host contracts, not live deployment verification. |
| Edit | [Routes](../../config/routes/edit.rb) implement `Edit::Org` only, with canonical `edit.umaxica.org`, local `edit.org.localhost`, and configured `edit_staff` host inputs. Existing functionality includes dashboard, browser sign-in, OIDC callback/backchannel logout, and twelve publishing surface/audience cells for entries, publications, and archives. [ApplicationController](../../app/controllers/edit/org/application_controller.rb) uses browser RP authentication and Action Policy with client `edit-org`. No MCP route is declared there. |
| Former Base/Side MCP | All six `resource :mcp, only: :create` declarations are commented out in [Base routes](../../config/routes/base.rb) and Warp routes. `config/routes/side.rb` does not exist in this worktree; the current namespace/file is Warp. The old public PoC is withdrawn, not a currently enabled public endpoint. |

### Retained PoC and dependency

[The MCP concern](../../app/controllers/concerns/mcp_endpoint.rb) constructs a per-request server
with stateless Streamable HTTP transport, explicit allowed hosts, `no-store`, surface context,
and a per-IP rate limit. The retained Base and Warp app/com/org `McpsController` classes use
bare authentication mode. Representative controllers are
[Base app](../../app/controllers/base/app/mcps_controller.rb) and
[Warp app](../../app/controllers/warp/app/mcps_controller.rb). This is not the proposed authenticated
connection authorization implementation.

The three retained read-only tools are
[liveness](../../app/adapters/mcp_liveness_tool.rb),
[revision](../../app/adapters/mcp_version_tool.rb), and
[service identity](../../app/adapters/mcp_service_info_tool.rb).
[McpSurfaceIdentity](../../app/values/mcp_surface_identity.rb) currently accepts `base` and `warp`
realms and app/com/org surfaces, not Edit. [Gemfile.lock](../../Gemfile.lock) pins `mcp` to `1.7.0`;
that version alone does not establish conformance with the target specification.

[Withdrawal tests](../../test/integration/mcp_endpoint_withdrawal_test.rb) assert route rejection
and not-found responses for the six former hosts.
[Identity value tests](../../test/values/mcp_surface_identity_and_token_codec_test.rb) also remain.
These tests were read, not executed during this documentation task.

The requested `notes/implementation/2026-08-13-mcp-unauthenticated-poc.md` is absent; the historical
note exists at [research/implementation/2026-08-13-mcp-unauthenticated-poc.md](../../research/implementation/2026-08-13-mcp-unauthenticated-poc.md).
Its old test paths and earlier behavior are historical, not evidence of current availability.
The retained Base/Side-origin PoC remains a future reconciliation or retirement topic; no code,
route, dependency, or test is changed by this proposal.

### Identity, Account, and authorization vocabulary

| Surface | Identity binding | Concrete Account model in this worktree | Storage family |
| --- | --- | --- | --- |
| app | [ClientIdentity](../../app/models/client_identity.rb) | [ClientPersona](../../app/models/client_persona.rb), table `personas` | app_zenith |
| com | [VisitorIdentity](../../app/models/visitor_identity.rb) | [Individual](../../app/models/individual.rb) | com_zenith |
| org | [OperatorIdentity](../../app/models/operator_identity.rb) | [Agent](../../app/models/agent.rb) | org_zenith |

The user's broad term “Persona” means Account in this proposal. In current Ruby code,
[Persona](../../app/models/concerns/persona.rb) is an interface concern, not the concrete app model.
Identity binding records are not interchangeable with runtime principals `Client`, `Visitor`, and
`Operator`, nor do their associations alone prove current authority. The
[accepted naming and authority ADR](../../adr/surface-account-collective-model-naming.md) separates
surface-local ownership/grants from Identity bindings.

[Actor](../../app/models/actor.rb) is a read facade over an installed `ActorValuesContext`;
[ApplicationPolicy](../../app/policies/application_policy.rb) consumes actor/user context and
applies capability restrictions. These are existing reuse boundaries, not proof that an MCP
bearer request can already construct an authorized context.

### Existing decisions requiring reconciliation

- [Base/Auth authority ADR](../../adr/base-auth-ceremony-and-seven-rp-boundary.md) makes Base the
  sole **physical** IdP/AS and Auth ceremony-only, while Acme remains conceptual vocabulary.
  The earlier [Acme/Sign/Core/Base/Palm ADR](../../adr/acme-sign-core-base-port-boundary.md) is
  partially superseded. Preserve the user's Acme-only direction, but review issuer/host and
  responsibility mapping explicitly; do not infer a separate Acme deployment or move authority.
  Base administering connections without serving MCP is compatible in principle with hosting
  OAuth authority, but that mapping is not newly decided here.
- [MCP withdrawal ADR](../../adr/mcp-endpoint-withdrawal.md) requires a follow-up ADR covering
  authentication, transport security, and tool ownership before restoration. This backlog does
  not satisfy that gate. Its former six-host restoration framing also needs reconciliation with
  the four-slot direction, which excludes Base and adds Edit/org.
- That ADR's naming note and the [integrated Warp backlog](2026-09-24-integrated-auth-avatar-warp-plan.md)
  preserve historical `side` MCP identifiers, whereas current `McpSurfaceIdentity` and Warp
  controllers use `warp`. Record this mismatch for review; neither rename nor compatibility
  handling is authorized here.
- The [OAuth participation allowlist](../../adr/oidc-oauth-participation-allowlist-and-non-participant-surfaces.md)
  constrains authentication participants. Existing browser RP participation does not establish
  approval for MCP resource identities or OAuth client registrations.

## 5. Target Architecture

**Confirmed direction, not an implementation plan:** MCP clients obtain authorization from the
Acme authority and access only the appropriate Warp/app, Warp/com, Warp/org, or Edit/org Resource
Server boundary. Resource access validates its token, persistent connection authorization,
Identity/Account binding, and current policy authority. Base offers authenticated management of
those authorizations. Core retains its web responsibilities; Palm retains its separate native API
role. Neither becomes an MCP entry point.

The existing host inventory above is a starting point for review. Future MCP paths, discovery
locations, issuer/resource identifiers, deployment layout, and division of controllers/services
remain undecided. In particular, the old `/mcp` path is evidence, not approval to restore it.

## 6. Single Active Connection Invariant

For each Account and each applicable logical slot, the active OAuth connection authorization
count is at most one. The four slots are app/Warp, com/Warp, org/Warp, and org/Edit. This is a
product invariant, not a selected database key, table, index, or locking design.

| Successfully established new authorization | Authorization automatically revoked | Independent slot preserved |
| --- | --- | --- |
| app/Warp | Previous app/Warp authorization for the same Account | Other Accounts and slots |
| com/Warp | Previous com/Warp authorization for the same Account | Other Accounts and slots |
| org/Warp | Previous org/Warp authorization for the same Account | org/Edit |
| org/Edit | Previous org/Edit authorization for the same Account | org/Warp |

The limit counts durable OAuth connection authorizations, not HTTP requests, sockets, concurrent
Tool executions, browser sessions, or MCP protocol sessions. Access Token renewal and Refresh Token
rotation continue an existing authorization and do not trigger replacement. The exact successful
establishment/commit point, same-client reauthorization, and additional-scope consent semantics
remain open. A failed or malicious authorization attempt must not evict a legitimate connection;
review must define how successful replacement is made reliable under races and failures.

## 7. Authentication and Authorization Boundaries

**Confirmed direction:** reuse Acme OAuth/OIDC and the existing Rails authorization owners.
Restrict each Access Token to the target Resource Server, validate Identity-to-Account association
and current authority, and preserve TLD/surface isolation. Identity alone, token possession alone,
or an OAuth scope alone does not establish permission for every Tool operation.

**Open design:** determine how authenticated MCP requests install trusted Actor context and invoke
existing policies without inheriting an unrelated browser session or bypassing lifecycle controls.
Define audience and scope independently. Specify current-state checks before Tool execution,
including removed relationships, suspended principals, revoked grants, and ineligible Accounts.
No new authentication database, shared cross-surface authority model, or browser credential reuse
is approved by this document.

## 8. Connection Administration and Auditing

**Confirmed direction:** Base will provide authenticated functions to inspect connections, linked
Identity and Account, OAuth client, granted scopes, last-use time, usage audit history, and the
history of automatically replaced authorizations, and to revoke authorization manually.

These functions manage persistent OAuth connection authorization state, not MCP protocol sessions.
They do not make Base an MCP Resource Server. Their exact routes, policies, administrator scope,
step-up requirements, data placement, audit event granularity, and retention remain undecided.
History must distinguish automatic replacement from manual revocation without recording tokens
or sensitive Tool payloads. Review how last-use observations differ from authoritative audit events.

## 9. Security Risks and Failure Scenarios

The review must address the following; mechanisms remain open.

| Scenario | Required review outcome |
| --- | --- |
| Attacker repeatedly initiates authorization to evict a legitimate client | Replacement requires successful authorized establishment; rejected/abandoned attempts cannot cause eviction. Assess consent abuse and repeated valid replacement abuse. |
| Simultaneous authorizations on multiple devices | Preserve the one-active invariant and define successful completion, losers, retries, and failure recovery. |
| Database failure or partial OAuth/Zenith completion | Define fail-closed behavior and recovery without accidentally accepting two active grants. |
| Old JWT is unexpired after replacement or manual revocation | Define immediate rejection of the old authorization and its Access/Refresh Tokens, including cache and propagation behavior. |
| Token theft, reuse, or replay | Review token validation, replay protections, client identification, and need for sender binding such as DPoP. |
| Request races with revocation; Tool is already executing | Define pre-execution revalidation and the boundary between revoking future permission and stopping in-flight work. |
| Identity relationship or policy authority changes | Revalidate current permissions; prior consent cannot freeze obsolete authority. |
| Cross-TLD/surface token or Account substitution | Bind issuer, audience, Account, client, and slot correctly; prevent privilege escalation and confused-deputy behavior. |
| Audit/log disclosure or missing history | Keep secrets and sensitive request data out of logs; define durable events, integrity, access restrictions, and retention. |

## 10. Open Design Questions

### Connection state and database design

- Which database owns connection authorization, and should app/com/org have separate models?
- How should shared services and surface-specific models divide responsibility without creating
  cross-surface authority leakage?
- What canonical key identifies a connection slot and its Account? How do region and resource
  identifiers relate to the four product slots without silently adding more slots?
- Which PostgreSQL UNIQUE constraints and locks enforce the invariant? How are concurrent device
  authorizations, retries, and transaction failures handled?
- Where is the transaction boundary between OAuth authorization records and Zenith databases?
  What happens when either side fails, and how is fail-closed recovery achieved?

### OAuth/OIDC and protocol conformance

- How will MCP Protected Resource Metadata, Authorization Server Metadata, and Client ID Metadata
  Documents (CIMD) be published, validated, and trusted?
- How will Resource Indicators (RFC 8707), token audience, and scopes map to each Resource Server?
- How are Access Tokens and Refresh Tokens revoked, including immediate denial of unexpired JWTs
  from a replaced authorization? No introspection, token format, cache, or lookup strategy is selected.
- At what exact point does replacement commit? When does same-client reauthorization or additional
  scope acquisition constitute a new connection rather than continuation?
- What are the PKCE, issuer-validation, MFA, and step-up requirements? Is DPoP or another sender
  constraint necessary, and what replay/key lifecycle behavior would it require?
- Which official protocol revision and SDK will be validated at implementation time? How are
  unsupported legacy versions rejected without downgrade or fallback?

### Security, management, and existing architecture

- How are malicious eviction attempts, token replay, revocation races, and in-flight Tools handled?
- Which policy and Identity/Account checks run before each Tool execution, and how are the existing
  Actor and Action Policy boundaries reused safely?
- How are clients reliably identified, and what are audit event granularity and retention periods?
- How do Base administration permissions and same-surface visibility work, including replacement
  history and manual revocation?
- How should the Acme conceptual authority map to current Base physical authority? Which accepted
  decisions would require explicit future amendment, and how will MCP withdrawal conditions be met?
- What is the future disposition of the withdrawn Base/Warp PoC, old Side references, current Warp
  protocol identifiers, and the absent Edit MCP implementation? No cleanup is approved now.

## 11. Future Decision Checklist

All items below are pending, not execution tasks authorized by this document.

- [ ] Reconfirm the latest official MCP specification and reject legacy downgrade/fallback paths.
- [ ] Reconcile accepted ADRs, authority naming, MCP withdrawal gates, and protocol identifier drift.
- [ ] Confirm exact hosts, routes, resource/issuer identifiers, registrations, and deployment boundaries.
- [ ] Define Account binding, four canonical slots, and independent org/Warp versus org/Edit behavior.
- [ ] Decide successful replacement, reauthorization, scope changes, and token-continuation semantics.
- [ ] Decide storage ownership, uniqueness, locking, concurrency, transaction boundaries, and recovery.
- [ ] Decide metadata, PKCE, issuer/audience/scope validation, MFA/step-up, and sender binding.
- [ ] Demonstrate the intended immediate-revocation and pre-Tool authorization semantics in a future review.
- [ ] Define Base administration, audit events, history, retention, and secret-safe observability.
- [ ] Review abuse/failure scenarios, transport security, and tool ownership/data-exposure review rules.
- [ ] Obtain design and implementation approval through the repository's normal ADR/spec lifecycle.

## 12. Out of Scope

This task changes only this backlog document. It does not implement or finalize models, schemas,
migrations, constraints, locks, OAuth flows, Tool behavior, endpoints, UI, configuration, or tests.
It does not restore, remove, or modify the PoC. No ADR, GitHub Issue, commit, push, deployment, or
edge repository write is included. Existing unrelated worktree changes are preserved.

Verification for this task is limited to source/reference inspection and document checks. Rails,
MCP interoperability, deployment behavior, and security/concurrency behavior are not runtime-tested.
Recording this backlog does not authorize proceeding to implementation.

## 13. References

Local source links above refer to files inspected in the current worktree. Historical missing
paths are explicitly identified rather than presented as live links. Additional boundary sources:

- [Repository routing inventory](../../README.md)
- [Knowledge ownership](../../docs/reference/repository-knowledge-architecture.md) and
  [spec lifecycle](../../specs/README.md)
- [Acme/Sign/Core/Base/Palm architecture and supersession notices](../../docs/architecture/acme-sign-core-base-port.md)
- [Actor context ADR](../../adr/actor-current-facade.md), read with current Actor code; historical
  context descriptions are not a substitute for the current installed-context implementation.

Official external references opened on 2026-10-10 (reference selection is not a conformance audit):

- [MCP specification, 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28).
  The retrieved overview describes stateless requests; this does not remove the application's
  need to manage durable OAuth connection authorizations separately from protocol lifecycle.
- [MCP authorization specification, 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization).
  Revalidate its normative requirements and referenced metadata standards during design review.
- [RFC 8707: Resource Indicators for OAuth 2.0](https://www.rfc-editor.org/rfc/rfc8707).
  Resource targeting and scopes are distinct review concerns.
- [Official MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk).
  Review the chosen release against the official specification; retained PoC usage is not approval.
