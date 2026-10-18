# Action Policy sustainability and security audit — 2026-09-19

Commit `52b705253`. Static scans over `app/controllers/**` (859 controllers plus concerns) and
`app/policies/**` (366 top-level `*_policy.rb` files; 379 including subdirectories). Source was read
for every hit. Single-line regex scans can miss a lookup split across lines or one built inside a
service, so the counts are lower bounds.

## Authorization calls

- `authorize!` targets: 112 a looked-up resource, 76 the signed-in actor (`current_*`), 56 a model
  class, 7 a symbol.
- 57 files authorize only the signed-in actor. None of them looks up a record from `params` except
  through the actor's own associations (`current_x.assoc.find_by!`).
- `authorized_scope`: 0 uses. `verify_authorized_scoped`: not enabled. Collection visibility lives
  in controller queries.
- `allowed_to?`: 25 textual occurrences under `app/`. 6 are the TODO comments added on 2026-09-18 to
  the welcome and sign-in checkpoint controllers; the rest are calls (classified separately).

## Lookups of a model constant with `params` (9)

- `Palm::App::Sign::OutsController`, `SignOutNotice`: logout challenge lookups; ceremony.
- `Base::{App,Com,Org}::Organizations::MembershipsController`: stubs with no state change.
- `Base::App::GroupsController`: authorized by `AvatarGroupPolicy` against `Actor.selection`.
- `Base::App::GroupAvatarMembershipsController#create`: the group is authorized, but the avatar is
  any active avatar and `role` is taken from params as-is. Whether that is intended is undecided in
  `docs/architecture/sns-subject-resource-grill.md`.
- `BaseAppAvatarSocialGraphActions`: target avatar for follow/block/mute; public by nature.

## Operator authority

- `Operator` and `Client` define none of `has_role?`, `operator_or_manager?`, `can_view?`,
  `can_edit?`, `can_contribute?` (checked with `bin/rails runner`). The role helpers in
  `ApplicationPolicy` are unusable, and `OrgStaffPolicy` denies every operator. That denial is
  pinned as fail-closed by `test/controllers/base/org/staff_console_pages_test.rb`.
- `EnforcementCasePolicy` (`index?`, `show?`, `create?`, `release?`, `review_appeal?`) and
  `{Client,Visitor,Operator}Policy#purge_sessions?` allow any authenticated operator. `approve?`
  only adds "not the operator who applied it". Session purge also requires Step-Up.
- `OperatorLifecycleRequestPolicy` is referenced nowhere. Its `approve?` would let any other
  operator approve any request.

## Policy inventory

- No resource rule returns an unconditional `true`.
- 98 of the 366 top-level policies have neither the policy class nor its model referenced from
  controllers, services, operations, or views.
