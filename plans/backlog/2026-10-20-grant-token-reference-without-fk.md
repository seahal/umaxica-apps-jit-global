# Grant Token References Without a Foreign Key

Recorded 2026-10-20. Status: backlog, investigation required before any implementation.

## Problem

`OpAppGrant#client_token_id`, `OpComGrant#visitor_token_id` and `OpOrgGrant#operator_token_id` are
declared as `belongs_to` associations to the token tables, but the database has no foreign key.
`database_consistency` reports three
`ForeignKeyChecker ... should have a foreign key in the database` findings.

## Current design

- A grant's stable parent is its device session (`device_session_id`), which has a foreign key.
  `DeviceSessionRootAndRpBinding.add_rp_device_session_constraints!` drops the token foreign key on
  purpose after adding the device-session one (`adr/device-session-dbsc-device-id-boundary.md`).
- Tokens rotate and can be physically deleted, and the grant must survive that.
  `test/models/rp_session_test.rb` ("rp session remains when the rotating root row is physically
  deleted") pins this. Adding the foreign key on 2026-10-19 broke that test, so it was withdrawn.
- The user decided on 2026-10-19 to keep this lifecycle and leave the three findings open (D3 in
  `specs/database-consistency-remediation/decisions.md`).

## Possible direction, not decided

Treat `*_token_id` as a recorded fact (the token that issued the grant) rather than a parent
reference: replace `belongs_to` with explicit lookups where the token is read. This changes neither
the schema nor the lifecycle.

## Behavior the association carries today

Removing `belongs_to` alone is not behavior-preserving:

- The association is required, so creating a grant validates that the token row exists.
- The token side declares `has_many :op_*_grants, dependent: :restrict_with_exception`, so
  destroying a token that still has grants through Active Record raises. The rp_session test covers
  only a physical SQL delete.
- Callers pass the token through the association (`OpComGrant.create!(visitor_token: token, ...)`,
  `visitor_verification.rb`), and `bind_device_session_from_parent_token` derives
  `device_session_id` from `*_token_id`.

## Investigation required first

- Every reader of `grant.client_token` / `visitor_token` / `operator_token`, including `includes`,
  `joins` and inverse associations, and what each does when the token row is gone.
- Every writer of `*_token_id`, and whether the value has to stay the issuing token or follow
  rotation.
- Whether the column is still needed at all, given the device-session parent.
- The audit, revocation, back-channel logout and RP session paths that depend on it, plus
  `docs/mermaid/` state diagrams if a lifecycle axis is involved.
- Characterization tests for each path, written before the change is accepted.
