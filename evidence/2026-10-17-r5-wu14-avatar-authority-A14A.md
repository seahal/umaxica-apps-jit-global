# R5-WU14 Avatar authority boundary

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree.
Contract: `docs/architecture/avatar-authority-contract-proposal.md`, approved by the user (S) on
2026-10-17 as written, with the instruction that WU12 and WU15 follow the same pattern.

## Owner side (`/api/v0/avatar/:surface` on the realm Base host)

Shared `AvatarAuthorityApiEndpoint`: realm Base Self-RP private_key_jwt bound to the exact URL,
Access JWT for that client, live grant for its `sid`; actor from the token, root from the grant; the
existing ActorSupport context (selection, tld) is installed from that root; the persona field must
equal the root's selection. High-risk transfers re-check Step-Up at the owner under the root row
lock and answer `step_up_required` when unmet. Endpoints: app avatars (index/show/create/ update),
follows/blocks/mutes, groups and group avatar memberships, app/org ownership transfers
(create/accept/cancel), app/org selected image bytes, app/org dashboard identity, app/com/org
switcher, org selected avatar (show/update/destroy).

## RP side

`AvatarAuthorityClient` + `AvatarRemoteResultPolicy`. Base app/com/org Avatar pages relay the
owner's answers; owner-lock denials stay 403, policy refusals use the authorization handler, Step-Up
requests start the existing ceremony, unreachable owner → 503.

## Results

- Avatar, groups, social graph, transfers, images, org avatars, switchers, dashboards and Edit
  suites: 153 runs, 0 failures (plus 91 runs for switcher/dashboard slices). RuboCop clean.
- Not moved here: com/org accounts and organizations listings and com root (Organization membership,
  R5-WU15).
