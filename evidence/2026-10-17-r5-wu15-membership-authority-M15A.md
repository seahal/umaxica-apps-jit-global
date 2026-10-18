# R5-WU15 Organization membership boundary

Date: 2026-10-17 UTC. HEAD `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted worktree. Pattern
approved by the user with the Avatar contract (2026-10-17): WU15 follows the same S shape.

- Owner (`/api/v0/membership/:surface` on app/com/org Base): accounts list/show, organizations
  list/show (with membership summary), organization memberships list (same page contract: 1..400,
  malformed → 400) and show, and a membership decision endpoint for index/show/new/
  create/edit/update/destroy rules via `OrganizationMembershipPolicy`. Unsupported membership writes
  remain unsupported (RP still answers 422/204 after an owner allow); org memberships stay
  read-only.
- com dashboard identity added to the identity owner (com has no Avatar capability).
- RP: `MembershipAuthorityClient`, `MembershipRemoteResultPolicy` (an explicit `allowed: true` is
  required for decision answers), `BaseMembershipRelay`; Base app/com/org accounts, organizations,
  organization memberships and com root now relay. No Base RP controller calls
  `BaseSwitcherAuthority` in-process any more.
- Results: accounts/organizations/memberships suites (9 files) 50 runs, com dashboard slice and
  related 68 runs, 0 failures. RuboCop clean.
