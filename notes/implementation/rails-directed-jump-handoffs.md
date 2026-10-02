# Rails directed Jump handoff implementation notes

Implementation date: 2026-10-01.

The 2026-10-02 contract freeze supersedes the development blanket gate, Edit issuer retention
and legacy production Host Authorization retention recorded below. See
`notes/implementation/2026-10-02-rails-jump-contract-freeze.md` and the amended directed handoff ADR.
Plan: `plans/active/rails-jump-directed-handoff-rollout.md`.
Decision: `adr/jump-directed-rails-handoff-contract.md`.
Results: `evidence/2026-10-01-rails-directed-jump-handoffs-R8J4.md`.

## Implementation decisions and boundaries

The user explicitly approved implementation after the initial inventory-only request. Existing
uncommitted cache-policy and Edit work was retained. The separate permission to edit
`test/test_helper.rb` covered only its `SIGN` to `AUTH` issuer-selection name.

The former Palm ADR prohibited a browser launcher and session continuity. The user's requirement
for an external-browser Palm/Base/Auth round-trip supersedes that restriction; the new ADR records
the narrow change. Palm still owns no OAuth token issuance and does not authenticate its native
bearer API through cookies. Existing native completion schemes are retained as fixed delivery
targets after a verified Palm HTTPS callback. Coordinated native rollout must distinguish that
callback from app-link interception and update code redemption to use the Palm redirect URI.

The development public trust matrix is not specified. The implementation therefore disables
development Jump issuance rather than treating production issuer identity as development identity.
Enabling it requires the separately approved issuer, JWKS, signing kid, gateway trust and browser
return/session contract. This is a deployment limitation, not completed public development support.

Core surface issuer/JWKS identity is now `jp.*`. Stored bridge hosts, database defaults and legacy
Host Authorization remain pending a separate persistence/cutover plan. No migration is supplied;
existing artifacts and in-flight authentication lifetimes need separate deployment consideration.

Edit RP completion and issuer destination least privilege remain review work. The generic OIDC
handoff preserves Edit's existing same-site admission instead of forcing it into the approved RP
graph. Its pre-existing cross-site issuer implementation remains in the worktree. Publishing
audience namespaces do not change the issuer TLD: `Edit::Org::Publishing::Docs::App` is `EDIT_ORG`.

Signed POST ceremonies retain their request method and controls. Native custom-scheme delivery is
a separate protocol exception bound to a fixed client callback, verified Base return and browser
state. The security invariant records this exact exception; it does not approve arbitrary external
redirects or an additional Jump edge.

## Verification interpretation

The multi-surface Core integration fixture used private Base before this change. Its shared-domain
test session loses Core continuity when using public Base/Auth hosts. It now transports the Core
cookie explicitly for the callback, matching production host-only session separation. Runtime
session settings were not changed; development host separation is part of its pending contract.

The evidence record distinguishes local full-suite and final focused results from unverified
production gateway trust, reachable public JWKS, native device behavior and deployment. Retired
issuer/hostname aliases were not introduced for rollback; the rollout plan requires coordinated
token draining and preservation of the previous artifact and configuration references.
