# Sign-In Boundary Finalization Implementation Notes

## Context

- Task: lock the accepted sign-in routing contract, harden the Acme ↔ Sign boundary, and resolve the
  Acme app `base-rails-rp` self-RP ambiguity without reintroducing `/auth/*`.
- Date: 2026-06-21.
- Existing worktree state: preserved unrelated dirty files in `adr/logout-ceremony-boundary.md`,
  `docs/identity/authority-boundary.md`, `docs/security/logout-sequence.md`, GH issue #833,
  `test/controllers/acme/com/oidc/logouts_controller_test.rb`,
  `test/controllers/acme/org/oidc/logouts_controller_test.rb`,
  `test/controllers/sign/app/sign_outs_controller_test.rb`, and
  `test/controllers/sign/route_naming_test.rb`.

## Evidence And Decision

- I traced the Acme app, com, and org authority/callback paths, plus the shared OIDC initiator and
  callback concerns.
- `base-rails-rp` is still a live client id for Base launcher flows and Acme's local browser flow.
- The Acme authority login and the later callback login share the same browser transport, but the
  callback remains a required product-browser boundary because it is still shared by Base launcher
  flows and the Acme local browser flow.
- Because `base-rails-rp` has other legitimate uses, the self-RP path was not collapsed. The final
  decision is End state B: keep the intentional product RP boundary and document it clearly.

## Implementation Changes

- Updated the Acme callback controller comments to describe `base-rails-rp` as the shared browser RP
  client instead of a Base-owned route.
- Renamed the Acme callback controller tests so they describe the shared browser RP client id
  accurately.
- Updated the authority-boundary, sign-in-sequence, and Acme RP boundary naming docs to explain the
  intentional product RP boundary and the live `base-rails-rp` client id.

## Notes

- No runtime `/auth/*` route was reintroduced.
- The sign-out contract was left intact.
- The Acme app callback route remains public because it is still needed for the documented product
  browser RP boundary and the shared `base-rails-rp` client.
