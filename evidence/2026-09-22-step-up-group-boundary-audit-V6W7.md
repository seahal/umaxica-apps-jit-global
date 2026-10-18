# Step-Up group boundary audit

Date: 2026-09-22
HEAD: 91d71c6f61d60c13be350bff3b723e05d09adf37
Branch: `feature`
Worktree: already dirty; no unrelated changes were reverted, staged, committed, or pushed.

## Result

No production change was made. The inspected Avatar Group and Group Avatar Membership writes are
authenticated and policy-authorized, but the repository does not currently define group membership
as ownership, representative authority, posting authority, or RBAC. Adding a new Step-Up gate to
these routes would therefore select an unresolved product/security contract rather than implement
an existing one.

## Evidence

- `app/controllers/base/app/full_access_controller.rb:6-17` supplies the selected-actor and full
  Base application lifecycle boundary. Its parent application controller still runs the existing
  authentication, restricted-session, verification, and authorization callbacks.
- `app/controllers/base/app/groups_controller.rb:7-53` authenticates the Client, requires the
  selected account through its parent, and applies `AvatarGroupPolicy` to create/update/archive
  operations. The controller describes Groups as Avatar containers and not posting actors.
- `app/controllers/base/app/group_avatar_memberships_controller.rb:6-40` authenticates the Client,
  scopes the group by public identifier and the membership through that group, and applies
  `GroupAvatarMembershipPolicy` before attach/reorder/detach operations.
- `app/policies/avatar_group_policy.rb:22-40` and
  `app/policies/group_avatar_membership_policy.rb:4-24` enforce Client/selected-account ownership
  boundaries but contain no role or representative-authority decision.
- `docs/architecture/umaxica-v1-architecture-lock.md:169-174` states that Group v1 is an Avatar
  container and not a posting, legal, organization, or authentication actor.
- `docs/architecture/sns-subject-resource-grill.md:1789-1810` leaves whether group membership
  confers representative authority explicitly unresolved and records the risk of guessing.

## Adversarial conclusion

The critical failure mode is not an observed missing callback; it is silently treating an unresolved
group semantic as a high-risk authority operation. The current evidence is insufficient to choose a
Step-Up scope, required AAL, affected actions, or recovery behavior. No Step-Up implementation or
test was invented. The question remains a bounded follow-up for the Persona/Avatar authority and
RBAC decision gate.

This audit does not claim that every sensitive write in the repository is complete. Identity
credential/security writes, session-revoke operations, withdrawal, recovery, social linking, and
administrative enforcement retain their existing dedicated verification or ceremony paths and must
be reviewed against their own contracts.

## Verification

This was a read-only source and documentation audit. No external service was contacted and no
database mutation was performed. The focused Compose-backed Rails contract set was rerun after the
audit:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/base/app/groups_controller_test.rb \
  test/controllers/base/app/avatars/social_graph_controllers_test.rb \
  test/integration/step_up_authentication_test.rb \
  test/integration/step_up_required_response_shape_test.rb \
  test/integration/sign/app/credential_removal_constraints_test.rb
```

Result: `50 runs, 194 assertions, 0 failures, 0 errors, 0 skips`.

This documentation-only audit did not alter production behavior or weaken CSRF, authentication,
authorization, rate limiting, or Step-Up controls.

Status: `NEXT_CYCLE / CONTRACT_UNDEFINED` for group-specific Step-Up classification.
