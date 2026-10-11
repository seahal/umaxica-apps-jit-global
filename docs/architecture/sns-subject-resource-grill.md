# SNS Subject Resource Model Grill

## Executive Summary

What exists:

- `Avatar` is the only model in this repository that clearly behaves like the canonical SNS actor:
  it has follow, block, mute, handle, moniker, assignment, and ownership associations in
  [app/models/avatar.rb](app/models/avatar.rb).
- Public SNS interaction is currently Avatar-to-Avatar for follows, blocks, and mutes in
  [app/models/avatar_follow.rb](app/models/avatar_follow.rb),
  [app/models/avatar_block.rb](app/models/avatar_block.rb), and
  [app/models/avatar_mute.rb](app/models/avatar_mute.rb).
- Handle history is represented by `Handle` and `HandleAssignment` in
  [app/models/handle.rb](app/models/handle.rb) and
  [app/models/handle_assignment.rb](app/models/handle_assignment.rb).
- Moniker history is partially represented by `AvatarMoniker` in
  [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb).
- Selection and switcher flows already carry `account_public_id`, `organization_public_id`,
  `organization_unit_public_id`, and optional `avatar_public_id` in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb),
  [app/services/acme_selector_authority.rb](app/services/acme_selector_authority.rb), and
  [app/services/acme_switcher_authority.rb](app/services/acme_switcher_authority.rb).

What does not exist:

- No `Post` model was found among the inspected model inventory; the repository only shows
  Avatar-centric social primitives, not a post/publication data model, in
  [app/models/avatar.rb](app/models/avatar.rb),
  [app/models/avatar_follow.rb](app/models/avatar_follow.rb),
  [app/models/avatar_block.rb](app/models/avatar_block.rb), and
  [app/models/avatar_mute.rb](app/models/avatar_mute.rb).
- No generic `Group` model class was found in the inspected model inventory; the current hierarchy
  uses `Enterprise`, `Bureau`, and `Company` plus their unit tables in
  [app/models/enterprise.rb](app/models/enterprise.rb),
  [app/models/bureau.rb](app/models/bureau.rb), [app/models/company.rb](app/models/company.rb),
  [app/models/enterprise_unit.rb](app/models/enterprise_unit.rb),
  [app/models/bureau_unit.rb](app/models/bureau_unit.rb), and
  [app/models/company_unit.rb](app/models/company_unit.rb).
- No `ClientGroup`, `VisitorGroup`, or `OperatorGroup` models exist yet in the inspected repository
  files.

What is ambiguous:

- `actor_id` is polymorphic in `Chronicle` and therefore does not identify a specific SNS actor
  class by itself in [app/models/chronicle.rb](app/models/chronicle.rb).
- `AvatarAssignment` and `AvatarMembership` both exist, but they represent different axes:
  role-based RBAC versus membership history, and the boundary is not obvious from the current naming
  alone in [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb) and
  [app/models/avatar_membership.rb](app/models/avatar_membership.rb).
- `Avatar` currently links to `member` through `client_id`, not to `Persona`, `Agent`, or
  `Individual`, in [app/models/avatar.rb](app/models/avatar.rb). That is structurally important and
  not just naming drift.
- `representing_organization_id` exists on `Avatar`, but the repository evidence does not explain
  whether it is posting authority, representative authority, or simply stored projection state in
  [app/models/avatar.rb](app/models/avatar.rb).

What contradicts or only partially matches the confirmed target:

- The confirmed target says `Organization -> Account -> Avatar`, but the current selection/bootstrap
  graph is `principal -> identity -> account -> collective -> unit -> membership -> avatar` in
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)
  and [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- The repository currently represents `Account` as `Persona`, `Agent`, and `Individual`, each
  attached to a surface-specific identity, not to `Organization` directly, in
  [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb), and
  [app/models/individual.rb](app/models/individual.rb).
- `Avatar` is currently created with `client_id` and `owner_organization_id` in
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb),
  so the current chain is not DB-enforced as `Organization -> Account -> Avatar`.

Canonical actor status:

- `Avatar` is currently the clearest canonical SNS actor because the SNS-like interactions are all
  Avatar-to-Avatar and Avatar owns the handle/moniker/assignment/ownership structures in
  [app/models/avatar.rb](app/models/avatar.rb).

Organization -> Account -> Avatar status:

- The target chain is only partially represented today. `Account -> Identity` is DB-enforced in
  [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb), and
  [app/models/individual.rb](app/models/individual.rb), while `Avatar -> Member` is present through
  `client_id` in [app/models/avatar.rb](app/models/avatar.rb) and `Avatar -> Organization` is
  projected through string columns rather than foreign keys in
  [app/models/avatar.rb](app/models/avatar.rb) and
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb).

Top structural risks:

- Missing DB-enforced `Account -> Avatar` chain, because `Avatar` still points at `member` and
  `owner_organization_id` rather than at a surface account class in
  [app/models/avatar.rb](app/models/avatar.rb).
- `Avatar -> Member / Client` path is confirmed in [app/models/avatar.rb](app/models/avatar.rb) and
  [app/models/member.rb](app/models/member.rb), which may conflict with the target
  `Organization -> Account -> Avatar` path.
- `Persona` / `Agent` / `Individual` are currently the account layer, while `Client` / `Operator` /
  `Visitor` are principal layers; that split is explicit in
  [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb),
  [app/models/individual.rb](app/models/individual.rb),
  [app/models/client.rb](app/models/client.rb), [app/models/operator.rb](app/models/operator.rb),
  and [app/models/visitor.rb](app/models/visitor.rb).
- `actor_id` ambiguity remains unresolved in `Chronicle` and related audit tables because the column
  is polymorphic in [app/models/chronicle.rb](app/models/chronicle.rb).
- `AvatarAssignment` versus `AvatarMembership` is not yet clean enough to safely add `ClientGroup`,
  `VisitorGroup`, or `OperatorGroup` without an explicit naming and boundary decision in
  [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb) and
  [app/models/avatar_membership.rb](app/models/avatar_membership.rb).
- No `Group` model exists yet, so the product target must not be documented as already implemented.
- No `Post` model exists yet, so posting authority is still only a design target.
- The policies for `Avatar`, `AvatarAssignment`, `AvatarMembership`, `AvatarFollow`, `AvatarBlock`,
  and `AvatarMute` are empty stubs in
  [app/policies/avatar_policy.rb](app/policies/avatar_policy.rb),
  [app/policies/avatar_assignment_policy.rb](app/policies/avatar_assignment_policy.rb),
  [app/policies/avatar_membership_policy.rb](app/policies/avatar_membership_policy.rb),
  [app/policies/avatar_follow_policy.rb](app/policies/avatar_follow_policy.rb),
  [app/policies/avatar_block_policy.rb](app/policies/avatar_block_policy.rb), and
  [app/policies/avatar_mute_policy.rb](app/policies/avatar_mute_policy.rb).

## Confirmed Design Decisions

| Decision                                                                                                                 | Repository status                | Evidence                                                                                                                                                                                                                                                                                                                                  | Gap                                                                      |
| ------------------------------------------------------------------------------------------------------------------------ | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Canonical SNS actor is Avatar                                                                                            | matches                          | [app/models/avatar.rb](app/models/avatar.rb); Avatar owns follows, blocks, mutes, assignments, moniker history, and active handle                                                                                                                                                                                                         | None for the current SNS actor layer                                     |
| Posts, public profiles, mentions, follows, blocks, mutes, and ordinary SNS interaction should initially center on Avatar | partially matches                | Follows/blocks/mutes are Avatar-to-Avatar in [app/models/avatar_follow.rb](app/models/avatar_follow.rb), [app/models/avatar_block.rb](app/models/avatar_block.rb), [app/models/avatar_mute.rb](app/models/avatar_mute.rb)                                                                                                                 | No Post model or mention model is present                                |
| Account must belong to Organization                                                                                      | partially matches                | Account/collective selection uses [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb) and bootstrap creates membership in [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)                                                                           | No direct DB-enforced `Account -> Organization` foreign key was found    |
| Organization-less personal Account is not allowed                                                                        | partially matches                | Bootstrap always creates a collective and membership in [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)                                                                                                                                                                            | This is service-enforced, not clearly schema-enforced                    |
| Avatar belongs under Account                                                                                             | contradicts                      | `Avatar` belongs to `member` via `client_id` in [app/models/avatar.rb](app/models/avatar.rb)                                                                                                                                                                                                                                              | Current FK path is Avatar -> Member/Client, not Avatar -> Account        |
| Intended switcher UX is hierarchical Organization -> Account -> Avatar                                                   | partially matches                | `AcmeSelectableContext` and `AcmeSwitcherAuthority` carry all three IDs in [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb)                                                                                                                                                                             | Current selection is persisted as flat IDs on the session token          |
| Group is a container/collection of Avatars                                                                               | not represented yet              | No Group model file was found in the inspected model inventory                                                                                                                                                                                                                                                                            | Must be modeled explicitly                                               |
| Group is not a posting actor for now                                                                                     | not represented yet              | No Group model or posting model exists in the inspected files                                                                                                                                                                                                                                                                             | Must be kept separate from posting authority                             |
| Group should eventually have public_id, display/moniker, membership/access control, auditability                         | partially matches                | `public_id` and `moniker` patterns already exist in [app/models/avatar.rb](app/models/avatar.rb), [app/models/handle.rb](app/models/handle.rb), and [app/models/avatar_membership.rb](app/models/avatar_membership.rb)                                                                                                                    | No Group model, no group audit table                                     |
| Group model names should be surface-specific                                                                             | not represented yet              | No `ClientGroup`, `VisitorGroup`, or `OperatorGroup` files exist                                                                                                                                                                                                                                                                          | Naming decision remains open                                             |
| `@handle` initially resolves only to Avatar                                                                              | partially matches                | Avatar owns `Handle` and `HandleAssignment` in [app/models/avatar.rb](app/models/avatar.rb), [app/models/handle.rb](app/models/handle.rb), and [app/models/handle_assignment.rb](app/models/handle_assignment.rb)                                                                                                                         | No mention route/parser evidence was found for a public `@handle` lookup |
| Do not introduce `@@group` yet                                                                                           | not represented yet              | No group mention machinery exists in the inspected files                                                                                                                                                                                                                                                                                  | Future mention syntax remains unset                                      |
| `id`, `public_id`, `handle`, and `display/moniker` are separate concepts                                                 | partially matches                | `id` is the PK in [app/models/avatar.rb](app/models/avatar.rb); `public_id` appears separately; `handle` is on `Handle`; `moniker` is on `Avatar` and history tables                                                                                                                                                                      | Vocabulary is split across multiple models                               |
| `id` is the internal database primary key and must not be treated as public                                              | matches                          | Primary keys are standard `id` columns in the schema comments, while public lookup uses `public_id` in [app/models/avatar.rb](app/models/avatar.rb), [app/models/persona.rb](app/models/persona.rb), and [app/models/enterprise.rb](app/models/enterprise.rb)                                                                             | None                                                                     |
| `public_id` is a stable external reference                                                                               | matches                          | `public_id` is unique on [app/models/avatar.rb](app/models/avatar.rb), [app/models/handle.rb](app/models/handle.rb), [app/models/persona.rb](app/models/persona.rb), and the surface controllers resolve by `params[:id]` in [app/controllers/acme/app/organizations_controller.rb](app/controllers/acme/app/organizations_controller.rb) | None                                                                     |
| `handle` is Avatar’s @name-style identifier                                                                              | matches                          | `Handle` and `HandleAssignment` are Avatar-scoped in [app/models/handle.rb](app/models/handle.rb) and [app/models/handle_assignment.rb](app/models/handle_assignment.rb)                                                                                                                                                                  | None                                                                     |
| `display` is the product/design term and `moniker` is the current implementation term                                    | partially matches                | `moniker` is the implemented field in [app/models/avatar.rb](app/models/avatar.rb), [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb), and [app/models/individual.rb](app/models/individual.rb)                                                                                                  | No separate `display` column or model exists                             |
| Posting authority and representative authority are separate concepts                                                     | repository evidence insufficient | `representing_organization_id` exists on Avatar in [app/models/avatar.rb](app/models/avatar.rb), but its semantics are not explained in code                                                                                                                                                                                              | Must be decided before implementation                                    |
| Permission inheritance may be allowed later, but should not be implemented initially                                     | not represented yet              | Current Avatar RBAC is flat role/permission tables in [app/models/avatar_role.rb](app/models/avatar_role.rb), [app/models/avatar_permission.rb](app/models/avatar_permission.rb), and [app/models/avatar_role_permission.rb](app/models/avatar_role_permission.rb)                                                                        | No inheritance logic exists                                              |
| Avatar handle changes should have 24-hour cooldown and immutable history                                                 | partially matches                | `Handle.cooldown_until` and `HandleAssignment.valid_from/valid_to` exist in [app/models/handle.rb](app/models/handle.rb) and [app/models/handle_assignment.rb](app/models/handle_assignment.rb)                                                                                                                                           | No explicit 24-hour rule is implemented in code shown here               |
| Avatar display/moniker changes should also have 24-hour cooldown and immutable history                                   | partially matches                | `AvatarMoniker.valid_from/valid_to` exist in [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb)                                                                                                                                                                                                                                 | No cooldown column or cooldown policy is present                         |
| Last admin/owner removal, demotion, or revocation should be prohibited                                                   | partially matches                | Avatar has owner/admin role tables in [app/models/avatar.rb](app/models/avatar.rb), and membership tables enforce one active primary in [app/models/avatar_membership.rb](app/models/avatar_membership.rb)                                                                                                                                | No explicit last-admin/owner invariant was found in the inspected code   |

## Evidence Map

### Models

- [app/models/avatar.rb](app/models/avatar.rb): Avatar is the SNS hub model; it owns `Handle`,
  `HandleAssignment`, `AvatarMoniker`, `AvatarMembership`, `AvatarOwnershipPeriod`,
  `AvatarAssignment`, and social edges.
- [app/models/handle.rb](app/models/handle.rb): stores the handle string, `public_id`,
  `cooldown_until`, and `is_system` state.
- [app/models/handle_assignment.rb](app/models/handle_assignment.rb): records temporal handle
  history with `valid_from`/`valid_to` and `assigned_by_actor_id`.
- [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb): records temporal moniker history
  with `valid_from`/`valid_to` and `set_by_actor_id`.
- [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb): role-based Avatar RBAC with
  owner/affiliation/administrator/editor/reviewer/viewer.
- [app/models/avatar_membership.rb](app/models/avatar_membership.rb): temporal membership records
  with `valid_from`/`valid_to`, `actor_id`, `granted_by_actor_id`, and `role_id`.
- [app/models/avatar_role.rb](app/models/avatar_role.rb),
  [app/models/avatar_permission.rb](app/models/avatar_permission.rb),
  [app/models/avatar_role_permission.rb](app/models/avatar_role_permission.rb): Avatar
  role/permission lookup tables.
- [app/models/avatar_follow.rb](app/models/avatar_follow.rb),
  [app/models/avatar_block.rb](app/models/avatar_block.rb),
  [app/models/avatar_mute.rb](app/models/avatar_mute.rb): Avatar-to-Avatar social relations.
- [app/models/client.rb](app/models/client.rb), [app/models/operator.rb](app/models/operator.rb),
  [app/models/visitor.rb](app/models/visitor.rb): current authenticated principals.
- [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb),
  [app/models/individual.rb](app/models/individual.rb): current account-like models.
- [app/models/enterprise.rb](app/models/enterprise.rb),
  [app/models/bureau.rb](app/models/bureau.rb), [app/models/company.rb](app/models/company.rb):
  current organization-like models.
- [app/models/enterprise_unit.rb](app/models/enterprise_unit.rb),
  [app/models/bureau_unit.rb](app/models/bureau_unit.rb),
  [app/models/company_unit.rb](app/models/company_unit.rb): current unit/child-container models.
- [app/models/member.rb](app/models/member.rb),
  [app/models/client_member.rb](app/models/client_member.rb),
  [app/models/client_account.rb](app/models/client_account.rb): the current Avatar/Member and RP
  account path on the app surface.
- [app/models/chronicle.rb](app/models/chronicle.rb): audit model with polymorphic `actor` and
  `subject`.

### Schema / Migrations

- [app/models/avatar.rb](app/models/avatar.rb): schema comment shows `client_id`,
  `owner_organization_id`, `representing_organization_id`, `active_handle_id`, and `public_id`.
- [app/models/handle.rb](app/models/handle.rb): schema comment shows `cooldown_until`, `handle`,
  `is_system`, and `public_id`.
- [app/models/handle_assignment.rb](app/models/handle_assignment.rb): schema comment shows
  `valid_from`, `valid_to`, `assigned_by_actor_id`, `avatar_id`, and `handle_id`.
- [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb): schema comment shows `moniker`,
  `valid_from`, `valid_to`, and `set_by_actor_id`.
- [app/models/avatar_membership.rb](app/models/avatar_membership.rb): schema comment shows
  `actor_id`, `avatar_id`, `granted_by_actor_id`, `role_id`, `valid_from`, and `valid_to`.
- [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb): schema comment shows
  `avatar_id`, `user_id`, and `role`.
- [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb),
  [app/models/individual.rb](app/models/individual.rb): schema comments show 1:1 identity FKs and
  unique indexes on `client_identity_id`, `operator_identity_id`, and `visitor_identity_id`.
- [app/models/client_account.rb](app/models/client_account.rb),
  [app/models/operator_account.rb](app/models/operator_account.rb),
  [app/models/visitor_account.rb](app/models/visitor_account.rb): schema comments show one RP
  account per principal via unique `user_id` / `staff_id` / `visitor_id`.

### Controllers / Routes

- [config/routes/acme.rb](config/routes/acme.rb): defines selector, switcher, accounts,
  organizations, memberships, and avatars routes for app/com/org.
- [app/controllers/acme/app/selectors_controller.rb](app/controllers/acme/app/selectors_controller.rb):
  accepts `account_public_id`, `organization_public_id`, `organization_unit_public_id`,
  `collective_public_id`, `collective_unit_public_id`, and `avatar_public_id`.
- [app/controllers/acme/app/switchers_controller.rb](app/controllers/acme/app/switchers_controller.rb):
  switcher changes already-selected account/organization/avatar context.
- [app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb):
  uses `params[:id]` as Avatar `public_id` through `find_avatar!`.
- [app/controllers/acme/app/organizations_controller.rb](app/controllers/acme/app/organizations_controller.rb):
  resolves organizations by `public_id`.
- [app/controllers/acme/com/selectors_controller.rb](app/controllers/acme/com/selectors_controller.rb),
  [app/controllers/acme/org/selectors_controller.rb](app/controllers/acme/org/selectors_controller.rb):
  same selector pattern on com/org.
- [app/controllers/acme/com/switchers_controller.rb](app/controllers/acme/com/switchers_controller.rb),
  [app/controllers/acme/org/switchers_controller.rb](app/controllers/acme/org/switchers_controller.rb):
  switcher exists on all surfaces, but com/org are still stubbed.

### Policies / Services

- [app/policies/avatar_policy.rb](app/policies/avatar_policy.rb),
  [app/policies/avatar_assignment_policy.rb](app/policies/avatar_assignment_policy.rb),
  [app/policies/avatar_membership_policy.rb](app/policies/avatar_membership_policy.rb),
  [app/policies/avatar_follow_policy.rb](app/policies/avatar_follow_policy.rb),
  [app/policies/avatar_block_policy.rb](app/policies/avatar_block_policy.rb),
  [app/policies/avatar_mute_policy.rb](app/policies/avatar_mute_policy.rb): currently empty policy
  shells.
- [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb):
  bootstrap graph creation for account, collective, membership, and avatar.
- [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb): canonical
  selectable context read model.
- [app/services/acme_selector_authority.rb](app/services/acme_selector_authority.rb),
  [app/services/acme_switcher_authority.rb](app/services/acme_switcher_authority.rb):
  selector/switcher write and read surfaces.
- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb):
  surface-specific account/collective/member mapping for app/com/org.

### Tests / Specs

- [test/models/avatar_test.rb](test/models/avatar_test.rb): proves Avatar social and role
  associations.
- [test/models/handle_test.rb](test/models/handle_test.rb): proves handle presence, uniqueness,
  `cooldown_until`, and active-avatar restriction.
- [test/models/handle_assignment_test.rb](test/models/handle_assignment_test.rb): proves temporal
  handle history and one active assignment per avatar/handle.
- [test/models/avatar_moniker_test.rb](test/models/avatar_moniker_test.rb): proves moniker model
  validation exists.
- [test/controllers/acme/app/selector_controller_test.rb](test/controllers/acme/app/selector_controller_test.rb),
  [test/controllers/acme/app/switchers_controller_test.rb](test/controllers/acme/app/switchers_controller_test.rb),
  [test/controllers/acme/app/avatars_controller_test.rb](test/controllers/acme/app/avatars_controller_test.rb),
  [test/controllers/acme/app/organizations_controller_test.rb](test/controllers/acme/app/organizations_controller_test.rb):
  prove selector/switcher/routes use public IDs and selected session state.
- [test/controllers/acme/org/selector_controller_test.rb](test/controllers/acme/org/selector_controller_test.rb),
  [test/controllers/acme/org/switcher_controller_test.rb](test/controllers/acme/org/switcher_controller_test.rb),
  [test/controllers/acme/org/avatars_controller_test.rb](test/controllers/acme/org/avatars_controller_test.rb),
  [test/controllers/acme/org/organizations_controller_test.rb](test/controllers/acme/org/organizations_controller_test.rb):
  show the org-surface analogue.
- [test/services/acme/selector_bootstrap_authority_test.rb](test/services/acme/selector_bootstrap_authority_test.rb):
  likely the best test source for the current bootstrap graph shape.

### Docs / Plans / ADRs

- [docs/architecture/actor-naming.md](docs/architecture/actor-naming.md): documents
  Client/Operator/Visitor as runtime actors.
- [docs/architecture/current_context.md](docs/architecture/current_context.md): documents `Actor` as
  the request-local context facade.
- [docs/architecture/database-boundaries.md](docs/architecture/database-boundaries.md): documents
  surface database naming and the `avatar` boundary.
- [docs/identity/authority-boundary.md](docs/identity/authority-boundary.md): historical authority
  boundary context.
- [adr/acme-account-organization-bootstrap-boundary.md](adr/acme-account-organization-bootstrap-boundary.md):
  accepted bootstrap boundary for account/organization/title/quota direction.
- [adr/collective-hierarchy-model.md](adr/collective-hierarchy-model.md): accepted recursive
  collective hierarchy vocabulary.
- [adr/app-actor-client-naming.md](adr/app-actor-client-naming.md),
  [adr/org-actor-operator-naming.md](adr/org-actor-operator-naming.md),
  [adr/com-actor-visitor-naming.md](adr/com-actor-visitor-naming.md): surface actor naming.
- GH issue #828: current implementation plan for the account/organization/bootstrap layer.

### Frontend / Switcher Code

- [app/views/acme/shared/dashboards/show.html.erb](app/views/acme/shared/dashboards/show.html.erb):
  surfaces selector and switcher links.
- [app/views/acme/app/switchers/show.html.erb](app/views/acme/app/switchers/show.html.erb): shows
  current selection and candidate lists.

## Current Model Inventory

### Client

- Class: `Client`
- Namespace: top-level
- Database: `app_principal`
- Table: `clients`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `access_state`, `admin_locked_at`, `admin_locked_reason_code`,
  `admin_locked_reason_note`, `mfa_level_id`, `mfa_status_id`, `status_id`, `visibility_id`,
  `token_valid_after_at`, `withdrawn_at`, `deactivated_at`
- Associations: `has_one :rp_account`, `has_many :client_memberships`, `has_many :client_tokens`,
  `has_many :client_device_sessions`, `has_many :client_chronicles`,
  `has_many :assigned_avatars, through: :avatar_assignments`,
  `has_many :owned_avatars, through: :avatar_assignments`
- Validations: `public_id` uniqueness/length/format via `PublicId`; status/mfa helpers via included
  concerns
- Callbacks: `before_validation :normalize_public_id`, `before_validation :assign_public_id!`,
  `around_create :retry_on_public_id_collision`
- Relevant tests: [test/models/client_test.rb](test/models/client_test.rb) and the
  selector/bootstrap tests that instantiate `Client`
- Relevant docs: [docs/architecture/actor-naming.md](docs/architecture/actor-naming.md)

### Operator

- Class: `Operator`
- Namespace: top-level
- Database: `org_principal`
- Table: `operators`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `access_state`, `admin_locked_at`, `admin_locked_reason_code`,
  `admin_locked_reason_note`, `mfa_level_id`, `mfa_status_id`, `status_id`, `visibility_id`,
  `token_valid_after_at`, `withdrawn_at`, `deactivated_at`
- Associations: `has_one :rp_account`, `has_many :operator_workspace_accounts`,
  `has_many :staff_chronicles`, `has_many :operator_tokens`, `has_many :operator_device_sessions`
- Validations/callbacks: same `public_id` generation/normalization pattern as `Client`
- Relevant tests: [test/models/operator_test.rb](test/models/operator_test.rb) and
  selector/bootstrap controller tests
- Relevant docs: [docs/architecture/actor-naming.md](docs/architecture/actor-naming.md)

### Visitor

- Class: `Visitor`
- Namespace: top-level
- Database: `com_principal`
- Table: `visitors`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: same core access/state columns as `Client`/`Operator`
- Associations: `has_one :rp_account`, `has_many :visitor_tokens`,
  `has_many :visitor_device_sessions`, `has_many :visitor_chronicles`-style equivalents through the
  included concerns
- Relevant tests: [test/models/visitor_test.rb](test/models/visitor_test.rb)
- Relevant docs: [docs/architecture/actor-naming.md](docs/architecture/actor-naming.md)

### Persona

- Class: `Persona`
- Namespace: top-level
- Database: `app_zenith`
- Table: `personas`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Account-like columns: `moniker`, `client_identity_id`
- Associations: `belongs_to :client_identity`, `has_many :persona_memberships`
- Validations: `client_identity_id` uniqueness
- Relevant tests:
  [test/models/persona_enterprise_model_layer_test.rb](test/models/persona_enterprise_model_layer_test.rb),
  [test/models/persona_membership_test.rb](test/models/persona_membership_test.rb)
- Relevant docs:
  [adr/acme-account-organization-bootstrap-boundary.md](adr/acme-account-organization-bootstrap-boundary.md)

### Agent

- Class: `Agent`
- Namespace: top-level
- Database: `org_zenith`
- Table: `agents`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Account-like columns: `moniker`, `operator_identity_id`
- Associations: `belongs_to :operator_identity`, `has_many :agent_memberships`
- Validations: `operator_identity_id` uniqueness
- Relevant tests:
  [test/models/agent_bureau_model_layer_test.rb](test/models/agent_bureau_model_layer_test.rb)

### Individual

- Class: `Individual`
- Namespace: top-level
- Database: `com_zenith`
- Table: `individuals`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Account-like columns: `moniker`, `visitor_identity_id`
- Associations: `belongs_to :visitor_identity`, `has_many :individual_memberships`
- Validations: `visitor_identity_id` uniqueness
- Relevant tests:
  [test/models/individual_company_model_layer_test.rb](test/models/individual_company_model_layer_test.rb)

### Enterprise

- Class: `Enterprise`
- Namespace: top-level
- Database: `app_zenith`
- Table: `enterprises`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `name`
- Associations: `has_many :enterprise_units`, `has_many :persona_memberships`
- Relevant tests:
  [test/models/enterprise_root_units_test.rb](test/models/enterprise_root_units_test.rb),
  [test/models/persona_enterprise_model_layer_test.rb](test/models/persona_enterprise_model_layer_test.rb)

### Bureau

- Class: `Bureau`
- Namespace: top-level
- Database: `org_zenith`
- Table: `bureaus`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `name`
- Associations: `has_many :bureau_units`, `has_many :agent_memberships`
- Relevant tests:
  [test/models/agent_bureau_model_layer_test.rb](test/models/agent_bureau_model_layer_test.rb)

### Company

- Class: `Company`
- Namespace: top-level
- Database: `com_zenith`
- Table: `companies`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `name`
- Associations: `has_many :company_units`, `has_many :individual_memberships`
- Relevant tests: [test/models/company_root_units_test.rb](test/models/company_root_units_test.rb),
  [test/models/individual_company_model_layer_test.rb](test/models/individual_company_model_layer_test.rb)

### EnterpriseUnit / BureauUnit / CompanyUnit

- These are collective child-container models with recursive parent/closure structures in
  [app/models/enterprise_unit.rb](app/models/enterprise_unit.rb),
  [app/models/bureau_unit.rb](app/models/bureau_unit.rb), and
  [app/models/company_unit.rb](app/models/company_unit.rb).
- Each has `public_id`, `name`, `parent_id`, and a surface-specific foreign key to its collective.
- Each uses a closure table for ancestor/descendant traversal.

### Member / ClientMember / ClientAccount

- `Member` in [app/models/member.rb](app/models/member.rb) is the current Avatar-side
  membership/rooting model on the app surface.
- `ClientMember` in [app/models/client_member.rb](app/models/client_member.rb) joins `Client` to
  `Member`.
- `ClientAccount` in [app/models/client_account.rb](app/models/client_account.rb) is the RP account
  row for `Client`.
- Relevant tests: [test/models/member_test.rb](test/models/member_test.rb)

### Avatar

- Class: `Avatar`
- Namespace: top-level
- Database: `avatar`
- Table: `avatars`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `moniker`, `active_handle_id`, `client_id`, `owner_organization_id`,
  `representing_organization_id`, `capability_id`, `image_data`
- Associations: `belongs_to :member, foreign_key: :client_id`, `belongs_to :capability`,
  `belongs_to :active_handle`, `has_many :handle_assignments`, `has_many :avatar_monikers`,
  `has_many :avatar_memberships`, `has_many :avatar_ownership_periods`,
  `has_many :avatar_assignments`, `has_many :outgoing_follows`, `has_many :incoming_follows`,
  `has_many :outgoing_blocks`, `has_many :outgoing_mutes`
- Validations: `public_id` uniqueness, `capability_id` numeric > 0, `moniker` presence
- Callbacks: Avatar creation-with-owner transaction in `create_with_owner`
- Relevant tests: [test/models/avatar_test.rb](test/models/avatar_test.rb)

### Handle

- Class: `Handle`
- Namespace: top-level
- Database: `avatar`
- Table: `handles`
- Primary key: `id :bigint`
- Public identifier: `public_id`
- Important columns: `handle`, `cooldown_until`, `is_system`, `handle_status_id`
- Associations: `has_many :handle_assignments`, `has_many :avatars`, `has_many :active_avatars`
- Validations: `handle` presence/uniqueness for non-system rows, `cooldown_until` presence,
  `public_id` uniqueness
- Relevant tests: [test/models/handle_test.rb](test/models/handle_test.rb)

### HandleAssignment

- Class: `HandleAssignment`
- Namespace: top-level
- Database: `avatar`
- Table: `handle_assignments`
- Primary key: `id :bigint`
- Public identifier: none
- Important columns: `handle_id`, `avatar_id`, `valid_from`, `valid_to`, `assigned_by_actor_id`,
  `handle_assignment_status_id`
- Associations: `belongs_to :handle`, `belongs_to :avatar`, `belongs_to :assigned_by_actor`
- Validations: one current assignment per handle and per avatar, `valid_from` presence
- Relevant tests: [test/models/handle_assignment_test.rb](test/models/handle_assignment_test.rb)

### AvatarMoniker

- Class: `AvatarMoniker`
- Namespace: top-level
- Database: `avatar`
- Table: `avatar_monikers`
- Primary key: `id :bigint`
- Public identifier: none
- Important columns: `avatar_id`, `moniker`, `valid_from`, `valid_to`, `set_by_actor_id`,
  `avatar_moniker_status_id`
- Associations: `belongs_to :avatar`, `belongs_to :avatar_moniker_status`
- Validations: avatar uniqueness while current, `moniker` presence, `valid_from` presence
- Relevant tests: [test/models/avatar_moniker_test.rb](test/models/avatar_moniker_test.rb)

### AvatarAssignment

- Class: `AvatarAssignment`
- Namespace: top-level
- Database: `avatar`
- Table: `avatar_assignments`
- Primary key: `id :bigint`
- Public identifier: none
- Important columns: `avatar_id`, `user_id`, `role`
- Associations: `belongs_to :avatar`, `belongs_to :user, class_name: "Client"`
- Validations: role inclusion, unique avatar/user/role tuple, unique owner and affiliation rows
- Relevant tests: [test/models/avatar_test.rb](test/models/avatar_test.rb)

### AvatarMembership

- Class: `AvatarMembership`
- Namespace: top-level
- Database: `avatar`
- Table: `avatar_memberships`
- Primary key: `id :bigint`
- Public identifier: none
- Important columns: `actor_id`, `avatar_id`, `granted_by_actor_id`, `valid_from`, `valid_to`,
  `role_id`, `avatar_membership_status_id`
- Associations: `belongs_to :avatar`, `belongs_to :avatar_membership_status`,
  `belongs_to :avatar_role`
- Validations: current uniqueness by `avatar_id` and `actor_id`, `actor_id` presence, `valid_from`
  presence
- Relevant tests: [test/models/avatar_membership_test.rb](test/models/avatar_membership_test.rb)

### AvatarRole / AvatarPermission / AvatarRolePermission

- `AvatarRole` defines fixed role IDs and links to `AvatarMembership` and permission rows in
  [app/models/avatar_role.rb](app/models/avatar_role.rb).
- `AvatarPermission` defines fixed permission IDs in
  [app/models/avatar_permission.rb](app/models/avatar_permission.rb).
- `AvatarRolePermission` links the two with a unique pair constraint in
  [app/models/avatar_role_permission.rb](app/models/avatar_role_permission.rb).

### AvatarFollow / AvatarBlock / AvatarMute

- `AvatarFollow` is a direct Avatar-to-Avatar edge in
  [app/models/avatar_follow.rb](app/models/avatar_follow.rb).
- `AvatarBlock` is a direct Avatar-to-Avatar edge with optional expiration and reason in
  [app/models/avatar_block.rb](app/models/avatar_block.rb).
- `AvatarMute` is a direct Avatar-to-Avatar edge with optional expiration in
  [app/models/avatar_mute.rb](app/models/avatar_mute.rb).

### Chronicle

- Class: `Chronicle`
- Namespace: top-level
- Database: `chronicle`
- Table: `chronicles`
- Primary key: `id :bigint`
- Public identifier: none
- Important columns: `actor_type`, `actor_id`, `subject_type`, `subject_id`, `action`, `result`,
  `reason`, `metadata`, `changeset`, `occurred_at`
- Associations: polymorphic `actor` and `subject`
- Relevance: `actor_id` is not a safe synonym for Avatar, Account, or Organization because the
  association is polymorphic

## Current Relationship Graph

### Actual Graph

The current repository graph, based only on actual associations and current selector/bootstrap code,
is:

```text
Client / Operator / Visitor
  -> identity (`ClientIdentity` / `OperatorIdentity` / `VisitorIdentity`)
    -> account (`Persona` / `Agent` / `Individual`)
      -> current_memberships (`PersonaMembership` / `AgentMembership` / `IndividualMembership`)
        -> collective (`Enterprise` / `Bureau` / `Company`)
          -> unit (`EnterpriseUnit` / `BureauUnit` / `CompanyUnit`)
            -> selectable context
              -> avatar (`Avatar`, app only)
                -> handle (`Handle` via `HandleAssignment`)
                -> moniker history (`AvatarMoniker`)
                -> role assignment (`AvatarAssignment`)
                -> membership history (`AvatarMembership`)
                -> social edges (`AvatarFollow` / `AvatarBlock` / `AvatarMute`)
```

Missing direct target edges are:

```text
Organization -x-> Account
Account -x-> Avatar
Organization -x-> Avatar
Group -x-> Avatar
```

These are represented only indirectly or by service-level projection today in
[app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb) and
[app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb).

### Confirmed Target Graph

```text
Identity
  -> Organization
    -> Account
      -> Avatar
        -> ClientGroup / VisitorGroup / OperatorGroup, if applicable
```

Current status against target:

- `Identity -> Organization`: partially represented through selection/bootstrap and identity/account
  setup, but not as a direct FK chain.
- `Organization -> Account`: not directly represented.
- `Account -> Avatar`: not directly represented.
- `Avatar -> Group`: not represented.

## Join / Intermediate Model Inventory

### Identity <-> Organization

- Current connection: indirect through selector/bootstrap and membership records.
- Evidence:
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)
  creates a collective and membership;
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb) resolves
  candidates through account memberships.
- Kind: membership/access projection.
- Temporal validity: yes, through membership `starts_at`, `ends_at`, and `revoked_at` in the
  membership concern.
- History preserved: yes, current membership rows are temporal.
- Uniqueness: primary-active constraints exist in
  [app/models/concerns/collective_membership.rb](app/models/concerns/collective_membership.rb).
- Tested: yes, via the selector/bootstrap and membership tests.
- Documented: partially, in the collective and bootstrap ADRs.

### Identity <-> Account

- Current connection: direct `Identity -> Account` via `has_one` in `ClientIdentity`,
  `OperatorIdentity`, and `VisitorIdentity`.
- Kind: ownership/one-to-one binding today.
- Temporal validity: no dedicated temporal join; it is a direct `has_one`.
- History preserved: only by replacing the row, not by a temporal join.
- Uniqueness: `source_record_id` is unique, so the binding is effectively 1:1 today in
  [app/models/client_identity.rb](app/models/client_identity.rb),
  [app/models/operator_identity.rb](app/models/operator_identity.rb), and
  [app/models/visitor_identity.rb](app/models/visitor_identity.rb).
- Tested: yes, by model layer tests.
- Documented: yes, in
  [adr/acme-account-organization-bootstrap-boundary.md](adr/acme-account-organization-bootstrap-boundary.md).

### Identity <-> Avatar

- Current connection: none direct in the inspected model graph.
- Current reality: Avatar points at Member/Client through `client_id` in
  [app/models/avatar.rb](app/models/avatar.rb).
- Temporal validity: not represented as a direct identity-avatar join.
- Tested: no direct identity-avatar join test found.
- Documented: only indirectly through bootstrap and selector docs.

### Organization <-> Account

- Current connection: membership through `PersonaMembership`, `AgentMembership`, and
  `IndividualMembership`.
- Kind: membership/placement/access.
- Temporal validity: yes, via `starts_at`, `ends_at`, `revoked_at`, and membership state/kind
  columns in membership models.
- History preserved: yes, temporal rows and `current` scopes exist in the shared membership concern.
- Uniqueness: one active primary membership per account is enforced in the concern.
- Scoped by organization: yes, each membership belongs to a specific collective and unit.
- Tested: yes, by the layer tests for Persona/Agent/Individual membership.
- Documented: yes, in [adr/collective-hierarchy-model.md](adr/collective-hierarchy-model.md).

### Account <-> Avatar

- Current connection: indirect and surface-specific through `Member`/`Client` and
  `AvatarAssignment`.
- Kind: ownership/role-based assignment.
- Temporal validity: `AvatarAssignment` is not temporal; `AvatarOwnershipPeriod` is temporal but is
  organization-focused rather than account-focused.
- History preserved: partial, via `HandleAssignment`, `AvatarMoniker`, and `AvatarOwnershipPeriod`,
  not via account ownership history.
- Uniqueness: Avatar assignment uniqueness exists by role tuple and special owner/affiliation
  constraints in [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb).
- Tested: yes, by [test/models/avatar_test.rb](test/models/avatar_test.rb).
- Documented: only indirectly.

### Avatar <-> Group-like concepts

- Current connection: none.
- Group-like replacement candidates in the codebase are `Enterprise`, `Bureau`, and `Company`, but
  they are collective containers, not Avatar groups.
- Tested/documented: no Avatar-group connection exists yet.

### Identity / Account / Organization / Avatar / Group <-> Role / Grant / Permission / Membership / Assignment

- Account-to-Organization membership exists through the surface-specific membership tables.
- Avatar-to-role/permission exists through `AvatarAssignment`, `AvatarMembership`, `AvatarRole`,
  `AvatarPermission`, and `AvatarRolePermission`.
- Representative authority is only hinted at through `representing_organization_id` and
  `AvatarOwnershipPeriod`; no explicit authority service was found.

## AvatarAssignment vs AvatarMembership

- Why do both exist? `AvatarAssignment` is current flat role assignment, while `AvatarMembership` is
  temporal membership with roles and lifecycle metadata in
  [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb) and
  [app/models/avatar_membership.rb](app/models/avatar_membership.rb).
- What lifecycle does each represent? `AvatarAssignment` looks like current-role projection;
  `AvatarMembership` looks like historical membership lifecycle.
- What cardinality does each represent? `AvatarAssignment` has one row per avatar/user/role tuple
  with special owner/affiliation uniqueness; `AvatarMembership` allows historical rows with
  uniqueness only for current rows.
- Which roles does each support? `AvatarAssignment` explicitly supports `owner`, `affiliation`,
  `administrator`, `editor`, `reviewer`, and `viewer`; `AvatarMembership` uses `role_id` to
  `AvatarRole`.
- Which one represents authority? `AvatarAssignment` is the clearer authority/permission surface
  today.
- Which one represents membership? `AvatarMembership` is the clearer membership surface today.
- Which one is temporal? `AvatarMembership` is temporal; `AvatarAssignment` is not.
- Which one is used by controllers/policies/services? `Avatar` uses assignments directly; policies
  are empty stubs; service code uses assignments and memberships for selection/ownership.
- Which one is tested? Both are covered, but `AvatarAssignment` has stronger direct behavior tests
  in [test/models/avatar_test.rb](test/models/avatar_test.rb).
- Could one be legacy? Possibly `AvatarAssignment`, but the repository does not say so explicitly.
- Are both needed? Repository evidence is insufficient to say.
- Is their boundary clear enough to safely add ClientGroup / VisitorGroup / OperatorGroup? No. The
  current boundary is too ambiguous.

## Authority / Access-Control Matrix

| Authority                   | Organization | Account     | Avatar      | Group-like  | Evidence                                                                                                                                                                | Gap                                 |
| --------------------------- | ------------ | ----------- | ----------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| admin/manage                | partial      | partial     | partial     | no evidence | Avatar RBAC tables in [app/models/avatar_role.rb](app/models/avatar_role.rb) and role assignments in [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb) | Group authority not defined         |
| operate/use                 | partial      | partial     | partial     | no evidence | current membership and selection flows in [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb)                                            | No group layer                      |
| read                        | partial      | partial     | partial     | no evidence | selectors/switchers/controllers in [config/routes/acme.rb](config/routes/acme.rb)                                                                                       | No explicit read matrix             |
| write                       | partial      | partial     | partial     | no evidence | controller write paths in [app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb) and selector/switcher authorities            | No group write policy               |
| visible/view-only           | partial      | partial     | partial     | no evidence | public lookups by `public_id` in controllers                                                                                                                            | No group visibility model           |
| representative              | unclear      | unclear     | partial     | no evidence | `representing_organization_id` on Avatar in [app/models/avatar.rb](app/models/avatar.rb)                                                                                | Semantics unresolved                |
| posting                     | no evidence  | no evidence | no evidence | no evidence | No Post model exists                                                                                                                                                    | Must be designed                    |
| invite                      | partial      | partial     | partial     | no evidence | membership models and invitations in `organization_invitation`                                                                                                          | Group invitation not present        |
| delegate/grant              | partial      | partial     | partial     | no evidence | `granted_by_actor_id` in [app/models/avatar_membership.rb](app/models/avatar_membership.rb)                                                                             | Meaning of actor is ambiguous       |
| ownership                   | partial      | partial     | partial     | no evidence | `AvatarAssignment` owner role and `AvatarOwnershipPeriod`                                                                                                               | Need explicit invariant             |
| creator/founder             | no evidence  | no evidence | no evidence | no evidence | not represented in inspected files                                                                                                                                      | Must be decided                     |
| revocation                  | partial      | partial     | partial     | no evidence | revocation columns in membership models and block/mute expiry columns                                                                                                   | No last-owner safety rule found     |
| audit/history visibility    | partial      | partial     | partial     | no evidence | temporal rows and Chronicle in [app/models/chronicle.rb](app/models/chronicle.rb)                                                                                       | Actor identity is ambiguous         |
| last-admin/owner protection | partial      | partial     | partial     | no evidence | owner role exists in Avatar RBAC and primary membership uniqueness exists in collective memberships                                                                     | Explicit last-admin guard not found |

### Posting authority vs representative authority

- Does code separate them? Not clearly. `representing_organization_id` exists on Avatar in
  [app/models/avatar.rb](app/models/avatar.rb), but there is no dedicated authority service or
  policy for it.
- Does code conflate them? It may. The current Avatar creation path sets both
  `owner_organization_id` and `representing_organization_id` to the same collective in
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb).
- Is `representing_organization_id` present? Yes, as a string column on Avatar in
  [app/models/avatar.rb](app/models/avatar.rb).
- What does it mean? Repository evidence is insufficient.
- Who may set/change representation? Not determined in the inspected code.
- Is representation temporal? Not represented as temporal state in the inspected code.
- Is representation tested? No direct dedicated test was found.

## Switcher / Current-Context Inventory

- Intended UX from the code today is selector first, switcher second. `AcmeSelectorAuthority`
  prepares or selects the first context, and `AcmeSwitcherAuthority` changes already-selected
  context in [app/services/acme_selector_authority.rb](app/services/acme_selector_authority.rb) and
  [app/services/acme_switcher_authority.rb](app/services/acme_switcher_authority.rb).
- Current context storage uses public IDs, not internal IDs, in `selected_account_public_id`,
  `selected_collective_public_id`, `selected_collective_unit_public_id`, and
  `selected_avatar_public_id` in
  [app/models/concerns/selected_actor_context.rb](app/models/concerns/selected_actor_context.rb),
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb), and
  [app/controllers/concerns/actor_support.rb](app/controllers/concerns/actor_support.rb).
- Route hierarchy does not fully reflect the confirmed target hierarchy; it reflects current
  surface-local selector/switcher and CRUD scaffolding in
  [config/routes/acme.rb](config/routes/acme.rb).
- Switcher is hierarchical in data shape but flat in persistence: one session token receives
  selected IDs in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- Switcher enforces access control by rejecting non-candidates in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- Can a user switch to Account without Organization? Not through the candidate model in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- Can a user switch to Avatar without Account? Not through the candidate model in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb), because avatar
  candidates are built from account memberships.
- What happens if access is revoked mid-session? The inspected selector/switcher code does a live
  authorization check against current records in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- What happens if the selected Account is no longer under the selected Organization?
  `candidate_still_authorized?` re-checks the membership and should fail closed in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- What happens if the selected Avatar is no longer accessible? The avatar part of
  `candidate_still_authorized?` re-checks availability in
  [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb).
- Are invalid switching cases tested? Yes, selector and switcher controller tests cover invalid
  selection/switch paths in
  [test/controllers/acme/app/selector_controller_test.rb](test/controllers/acme/app/selector_controller_test.rb)
  and
  [test/controllers/acme/app/switchers_controller_test.rb](test/controllers/acme/app/switchers_controller_test.rb).

## Route / Controller Inventory

### Organizations

- App route: `resources :organizations` in [config/routes/acme.rb](config/routes/acme.rb)
- App controller:
  [app/controllers/acme/app/organizations_controller.rb](app/controllers/acme/app/organizations_controller.rb)
- Params: `params[:id]` resolved to `public_id`
- Auth: `authenticate_client!`
- Lookup method: `Enterprise.find_by!(public_id: params.expect(:id))`
- Surface: HTML and redirect behavior

- Com route: `resources :organizations` in [config/routes/acme.rb](config/routes/acme.rb)
- Com controller:
  [app/controllers/acme/com/organizations_controller.rb](app/controllers/acme/com/organizations_controller.rb)
- Params: `params[:id]` resolved to `public_id`
- Auth: `authenticate_visitor!`
- Lookup method: `Company.find_by!(public_id: params.expect(:id))`

- Org route: `resources :organizations` in [config/routes/acme.rb](config/routes/acme.rb)
- Org controller:
  [app/controllers/acme/org/organizations_controller.rb](app/controllers/acme/org/organizations_controller.rb)
- Params: `params[:id]` resolved to `public_id`
- Auth: `authenticate_operator!`
- Lookup method: `Bureau.find_by!(public_id: params.expect(:id))`

### Accounts

- App controller:
  [app/controllers/acme/app/accounts_controller.rb](app/controllers/acme/app/accounts_controller.rb)
- Com controller:
  [app/controllers/acme/com/accounts_controller.rb](app/controllers/acme/com/accounts_controller.rb)
- Org controller:
  [app/controllers/acme/org/accounts_controller.rb](app/controllers/acme/org/accounts_controller.rb)
- Route pattern: `resources :accounts` in [config/routes/acme.rb](config/routes/acme.rb)
- Current behavior: index only in the controller bodies inspected here; the richer account CRUD
  lives in the account-specific controllers not shown in this excerpt.

### Avatars

- App route: `resources :avatars` in [config/routes/acme.rb](config/routes/acme.rb)
- App controller:
  [app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb)
- Params: `params[:id]` treated as Avatar `public_id` in `find_avatar!`
- Auth: `authenticate_client!`
- Surface: HTML and redirect behavior

- Org route: `resources :avatars` in [config/routes/acme.rb](config/routes/acme.rb)
- Org controller:
  [app/controllers/acme/org/avatars_controller.rb](app/controllers/acme/org/avatars_controller.rb)
- Params: controller uses the current selected avatar context rather than a direct lookup in the
  excerpt shown
- Auth: `authenticate_operator!`

### Selector / Switcher / Current Context

- App selector:
  [app/controllers/acme/app/selectors_controller.rb](app/controllers/acme/app/selectors_controller.rb)
- App switcher:
  [app/controllers/acme/app/switchers_controller.rb](app/controllers/acme/app/switchers_controller.rb)
- Com selector:
  [app/controllers/acme/com/selectors_controller.rb](app/controllers/acme/com/selectors_controller.rb)
- Com switcher:
  [app/controllers/acme/com/switchers_controller.rb](app/controllers/acme/com/switchers_controller.rb)
- Org selector:
  [app/controllers/acme/org/selectors_controller.rb](app/controllers/acme/org/selectors_controller.rb)
- Org switcher:
  [app/controllers/acme/org/switchers_controller.rb](app/controllers/acme/org/switchers_controller.rb)
- Current context storage:
  [app/controllers/concerns/actor_support.rb](app/controllers/concerns/actor_support.rb) and
  [app/models/concerns/selected_actor_context.rb](app/models/concerns/selected_actor_context.rb)

### Missing routes

- No route or controller for a post/publication model was found.
- No route or controller for a `Group` model was found.
- No route or controller for mention syntax was found.
- The existing selector params include `collective_public_id`, but there is no separate `@@group` or
  group lookup route.

## Public Identifier / Handle / Display / Moniker Inventory

| Resource                                            | Internal ID | public_id | handle           | display/moniker         | history                  | cooldown                                       | Evidence                                                                                                                                                 | Gap                                    |
| --------------------------------------------------- | ----------- | --------- | ---------------- | ----------------------- | ------------------------ | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Organization-like (`Enterprise`/`Bureau`/`Company`) | yes         | yes       | no               | `name` / future `title` | no                       | no                                             | [app/models/enterprise.rb](app/models/enterprise.rb), [app/models/bureau.rb](app/models/bureau.rb), [app/models/company.rb](app/models/company.rb)       | display vocabulary not unified         |
| Account-like (`Persona`/`Agent`/`Individual`)       | yes         | yes       | no               | `moniker`               | no                       | no                                             | [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb), [app/models/individual.rb](app/models/individual.rb)         | no direct display model                |
| Avatar                                              | yes         | yes       | yes via `Handle` | `moniker`               | yes, via `AvatarMoniker` | handle has cooldown; moniker does not show one | [app/models/avatar.rb](app/models/avatar.rb), [app/models/handle.rb](app/models/handle.rb), [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb) | separate display vocabulary unresolved |
| Group-like                                          | no model    | no model  | no model         | no model                | no model                 | no model                                       | no Group model file found in inspected inventory                                                                                                         | Group layer must be created            |

Known handle rule from repository evidence:

- `Handle` validates presence, uniqueness for non-system rows, and `cooldown_until` presence in
  [app/models/handle.rb](app/models/handle.rb).
- The repository evidence shown here does not prove the exact `A-Z/a-z/0-9 max length 10` rule for
  handles. That rule is a product target, not a proven current behavior.

Assessments:

- Uniqueness global? `Handle` uniqueness is global for non-system rows in
  [app/models/handle.rb](app/models/handle.rb).
- Case sensitivity? Repository evidence here does not prove case sensitivity behavior.
- DB-enforced? Yes for uniqueness through indexes in [app/models/handle.rb](app/models/handle.rb).
- Reserved words? `is_system` provides a separate path, but reserved-word policy is not documented
  in code.
- Reuse of old handles? Not proven.
- Redirect of old handles? Not proven.
- Deleted/suspended reservations? Not proven.

## Moniker / Display Terminology Decision

- `display` is the product term.
- `moniker` is the current implementation term in [app/models/avatar.rb](app/models/avatar.rb),
  [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb), and
  [app/models/individual.rb](app/models/individual.rb).
- Repository evidence currently supports option A: `display` maps to `moniker` at the implementation
  layer.
- It does not yet support a separate `display` model or a proof that `display` and `moniker` are
  distinct concepts.
- It also does not yet justify a separate `Display` model or column.

## Handle / Display History and Cooldown Interrogation

- Does `HandleAssignment` satisfy immutable handle history? Mostly yes, because it stores
  `valid_from` and `valid_to` and enforces one current assignment per handle/avatar in
  [app/models/handle_assignment.rb](app/models/handle_assignment.rb).
- Does `AvatarMoniker` satisfy immutable display/moniker history? Partially yes, because it stores
  `valid_from` and `valid_to` in [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb).
- Does cooldown apply only to `Handle`? The only explicit cooldown column found is `cooldown_until`
  on `Handle` in [app/models/handle.rb](app/models/handle.rb).
- Is there moniker cooldown? No explicit cooldown column was found for `AvatarMoniker`.
- Are actor/editor fields sufficient? `assigned_by_actor_id` and `set_by_actor_id` exist, but the
  actor type is ambiguous.
- Should explicit identity/account/organization context columns be added later? Repository evidence
  does not answer this; it is a design decision.
- Should admin override exist? Not documented in the inspected code.
- Should old handles be reserved? Not documented.
- Should failed attempts be audited? Not represented in the inspected code.

## Actor Ambiguity

Columns with `actor_id` or `*_by_actor_id` should be treated as ambiguous unless the model itself
pins them down:

| Table                      | Column                    | FK target / association                                | Meaning from code               | Audit risk                         |
| -------------------------- | ------------------------- | ------------------------------------------------------ | ------------------------------- | ---------------------------------- |
| `chronicles`               | `actor_id`                | polymorphic `actor`                                    | actor of an audit event         | high if interpreted as Avatar only |
| `handle_assignments`       | `assigned_by_actor_id`    | `belongs_to :assigned_by_actor, class_name: "Avatar"`  | Avatar that assigned the handle | moderate, but explicit for Avatar  |
| `avatar_monikers`          | `set_by_actor_id`         | no association declared in the inspected file          | unknown                         | high                               |
| `avatar_memberships`       | `actor_id`                | no explicit association declared in the inspected file | unknown                         | high                               |
| `avatar_memberships`       | `granted_by_actor_id`     | no explicit association declared in the inspected file | unknown                         | high                               |
| `avatar_ownership_periods` | `transferred_by_actor_id` | no explicit association declared in the inspected file | unknown                         | high                               |

Do not claim these mean Avatar, Identity, Account, or system actor unless the FK or association
proves it.

## Group Findings

Confirmed:

- Group is intended to be an Avatar container.
- Group is not a posting actor for now.
- Group is a managed resource.
- Model names should be surface-specific: `ClientGroup`, `VisitorGroup`, and `OperatorGroup`.

What the repository actually has:

- `Enterprise`, `Bureau`, and `Company` are the current collective/container models in
  [app/models/enterprise.rb](app/models/enterprise.rb),
  [app/models/bureau.rb](app/models/bureau.rb), and [app/models/company.rb](app/models/company.rb).
- `EnterpriseUnit`, `BureauUnit`, and `CompanyUnit` are the current recursive child-container models
  in [app/models/enterprise_unit.rb](app/models/enterprise_unit.rb),
  [app/models/bureau_unit.rb](app/models/bureau_unit.rb), and
  [app/models/company_unit.rb](app/models/company_unit.rb).
- None of those are documented as a Group abstraction.

Group-specific questions:

- Could these collective models be confused with Group? Yes, because they already own hierarchy and
  membership.
- Are they equivalent? No direct evidence says so.
- Why not? They already model collective hierarchy and account placement, not Avatar collections.
- What boundary should be kept? Keep collective hierarchy separate from Avatar-group semantics until
  the product vocabulary is resolved.
- Would reuse create authorization/routing/naming/multi-surface problems? Yes, likely, because the
  current collective naming already carries surface-specific meaning.

## Mention Syntax Questions

- `@handle` initially resolving only to Avatar is consistent with current Avatar/Handle ownership in
  [app/models/avatar.rb](app/models/avatar.rb), [app/models/handle.rb](app/models/handle.rb), and
  [app/models/handle_assignment.rb](app/models/handle_assignment.rb).
- There is no `@@group` syntax support in the inspected repository files.
- Mention lookup, autocomplete, notifications, markdown/rich text, and search indexing for Avatar
  mentions are not represented in the inspected files.

## SNS Subject Model Interrogation

- Are follows Avatar-to-Avatar? Yes, in [app/models/avatar_follow.rb](app/models/avatar_follow.rb).
- Are blocks Avatar-to-Avatar? Yes, in [app/models/avatar_block.rb](app/models/avatar_block.rb).
- Are mutes Avatar-to-Avatar? Yes, in [app/models/avatar_mute.rb](app/models/avatar_mute.rb).
- Are posts authored by Avatar, if Post exists? No Post model was found.
- Are public profiles Avatar-centered? The current Avatar model is the profile-like SNS object, but
  no separate profile model was found.
- Are notifications Avatar-centered? No dedicated SNS notification model was found in the inspected
  files.
- Does any code expose Identity as public SNS actor? Not in the inspected SNS files; the public SNS
  primitives center on Avatar.
- Does any code allow Account/Organization/Group to author posts? No post model exists to prove
  that.
- Can Avatar exist without Account? The current `Avatar` schema and bootstrap path suggest it is
  tied to `client_id` and ownership context in [app/models/avatar.rb](app/models/avatar.rb) and
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb).
- Can Account exist without Organization? The selector/bootstrap path always creates a collective
  and membership in
  [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb),
  but the repository evidence shown here does not prove a DB-level prohibition.
- Can Avatar be transferred between Accounts? The current code shows ownership and handle history,
  but no direct transfer service was inspected.
- Can Avatar represent Organization? The code stores `representing_organization_id`, but the meaning
  is unresolved.
- Is representation temporal or current-only? The inspected code does not prove temporal
  representation.

## Data Integrity Risks

- Required relationships: `Persona`/`Agent`/`Individual` require identity rows in
  [app/models/persona.rb](app/models/persona.rb), [app/models/agent.rb](app/models/agent.rb), and
  [app/models/individual.rb](app/models/individual.rb).
- `Account -> Organization` is currently enforced by membership logic, not a direct FK.
- `Avatar -> Account` is not directly enforced.
- `handle` uniqueness is DB-enforced for non-system rows in
  [app/models/handle.rb](app/models/handle.rb).
- `public_id` uniqueness exists across the visible subject models in the inspected files.
- `id` exposure risk remains if a controller or serializer leaks internal IDs instead of
  `public_id`.
- Last-admin/owner protection is not explicitly enforced in the inspected Avatar code.
- Temporal overlap constraints exist in the membership and handle history models, but no explicit
  cross-model overlap checks were inspected.
- Active handle uniqueness is currently enforced by `HandleAssignment` uniqueness and the
  `active_handle_id` foreign key path in [app/models/avatar.rb](app/models/avatar.rb) and
  [app/models/handle_assignment.rb](app/models/handle_assignment.rb).
- Concurrent demotion/revoke risk is not directly addressed in the inspected files.

## Authorization Risks

- Authorization is currently mostly empty at the Avatar policy layer in
  [app/policies/avatar_policy.rb](app/policies/avatar_policy.rb) and related empty policy files.
- The current code relies on direct membership/assignment checks in services and controllers more
  than on meaningful Avatar policy logic.
- Inheritance is not implemented for Avatar permissions in the inspected files.
- Representative versus posting authority is still conflated or at least not separated in code.
- Editing Avatar settings versus acting as Avatar is not clearly separated by policy.
- Cooldown override behavior is not represented.
- Authorization decisions are not durably audited in a dedicated SNS authorization table.

## Routing / API Risks

- Public URLs currently use `params[:id]` while resolving by `public_id` in controllers like
  [app/controllers/acme/app/organizations_controller.rb](app/controllers/acme/app/organizations_controller.rb)
  and
  [app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb).
- Internal admin URLs versus public URLs are not clearly separated for the SNS subject layer.
- JSON responses can still expose ambiguous `id` fields if future work is not careful.
- Nested route depth is already significant for selector/switcher/current-context flows in
  [config/routes/acme.rb](config/routes/acme.rb).
- There is no `/@avatar_handle` route in the inspected files.
- Avatar routes currently use `:id` in the route, but the controller treats it as `public_id`.
- Public/private route separation exists by surface, but not by SNS resource kind.

## Multi-Surface Vocabulary

| Product concept     | App surface    | Com surface  | Org surface   | Evidence                                                                                     | Notes                               |
| ------------------- | -------------- | ------------ | ------------- | -------------------------------------------------------------------------------------------- | ----------------------------------- |
| Account-like        | Persona        | Individual   | Agent         | [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb) | Matches the current selector config |
| Organization-like   | Enterprise     | Company      | Bureau        | [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb) | Matches the current selector config |
| Unit-like           | EnterpriseUnit | CompanyUnit  | BureauUnit    | [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb) | Matches the current selector config |
| Proposed Group-like | ClientGroup    | VisitorGroup | OperatorGroup | no code evidence                                                                             | Proposal only                       |

The rough mapping above is supported by
[app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb), but it
is still a configuration mapping, not a final product ontology.

## Gaps vs Confirmed Target

| Target decision                                      | Current implementation                     | Status              | Gap                              | Risk   | Suggested next step                                             |
| ---------------------------------------------------- | ------------------------------------------ | ------------------- | -------------------------------- | ------ | --------------------------------------------------------------- |
| Avatar canonical actor                               | Avatar-centered SNS primitives exist       | matches             | None for current SNS actor layer | Low    | Keep Avatar as the SNS actor                                    |
| Account requires Organization                        | membership-based selection exists          | partially matches   | no direct DB FK                  | Medium | Decide whether to add direct FK or preserve service enforcement |
| Avatar requires Account                              | Avatar links to Member/Client, not Account | contradicts         | wrong FK path                    | High   | Resolve Avatar ownership chain before adding new SNS features   |
| Group is Avatar container                            | no Group model exists                      | not represented yet | Group layer missing              | High   | Introduce group vocabulary and model shape                      |
| Group not posting actor                              | no Post model exists                       | not represented yet | posting semantics absent         | Medium | Keep posting separate until group model exists                  |
| `@handle` only Avatar                                | Handle/Avatar ownership exists             | partially matches   | no mention route/parser evidence | Medium | Define mention resolution and storage                           |
| `id` / `public_id` / `handle` / `display` separation | partially present                          | partially matches   | display not separate             | Medium | Lock vocabulary before schema work                              |
| handle cooldown/history                              | HandleAssignment + cooldown exist          | partially matches   | no explicit 24h rule shown       | Medium | Add explicit policy/tests if required                           |
| display/moniker cooldown/history                     | AvatarMoniker history exists               | partially matches   | no cooldown                      | Medium | Decide whether cooldown is needed                               |
| representative != posting                            | unresolved                                 | not represented yet | semantics unclear                | High   | Separate these before new authorization work                    |
| switcher Organization -> Account -> Avatar           | selector/switcher store all three IDs      | partially matches   | flat session projection          | Medium | Decide whether hierarchical read model is needed                |
| no permission inheritance now                        | flat RBAC tables exist                     | partially matches   | no inheritance yet               | Low    | Keep inheritance out of the first slice                         |
| last admin/owner protection                          | owner role and primary membership exist    | partially matches   | no explicit last-owner guard     | High   | Add explicit invariant before exposing group/admin UI           |

## Detailed Questions for the Designer

### Q01. What is the canonical public SNS noun?

Question: Should the user-facing noun be `Avatar` everywhere, or should the product eventually
expose a different public noun while keeping `Avatar` as the implementation class?

Why this matters: It determines route names, copy, and whether future docs should call the actor
layer by implementation or product language.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb)

What is unclear: Whether the product should keep `Avatar` as the public name or only as an internal
model name.

Candidate options:

- Option A: keep `Avatar` public and internal.
- Option B: expose a different product noun while keeping `Avatar` internally.
- Option C: split the noun by surface.

Recommended default: Option A.

Risk if unresolved: Copy and route naming will drift.

### Q02. Is `representing_organization_id` posting authority or representation metadata?

Question: What does `representing_organization_id` mean on `Avatar`?

Why this matters: It is the only explicit representation-looking column in the current Avatar
schema.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)

What is unclear: Whether this column is authority, presentation, or a temporary projection.

Candidate options:

- Option A: posting authority.
- Option B: representative authority.
- Option C: cached projection only.

Recommended default: Option C until proven otherwise.

Risk if unresolved: Authority and display state will be conflated.

### Q03. Should Avatar stay attached to `Member`, or move to Account?

Question: Should `Avatar` keep `belongs_to :member` through `client_id`, or be reparented to
`Persona`/`Agent`/`Individual`?

Why this matters: This is the biggest structural mismatch against the target chain.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/models/member.rb](app/models/member.rb)

What is unclear: Whether `Member` is intended to remain an internal wrapper or a legacy detour.

Candidate options:

- Option A: keep `Member` as the Avatar parent.
- Option B: add Account ownership first, then phase out Member attachment.
- Option C: replace Member attachment directly.

Recommended default: Option B.

Risk if unresolved: SNS authorization will keep depending on a non-target intermediate model.

### Q04. Should Group be introduced as a first-class model family now?

Question: Should `ClientGroup`, `VisitorGroup`, and `OperatorGroup` be introduced as first-class
models before any SNS posting work?

Why this matters: The product target says Group is a managed Avatar container, but the repository
has no such layer yet.

Current evidence:

- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)
- no Group model file in the inspected inventory

What is unclear: Whether group membership should reuse collective models or remain distinct.

Candidate options:

- Option A: introduce group models now.
- Option B: design the vocabulary now, implement later.
- Option C: reuse collective models as the group layer.

Recommended default: Option B.

Risk if unresolved: Group and collective semantics may be merged irreversibly.

### Q05. Is `@handle` lookup Avatar-only forever or only initially?

Question: Should `@handle` remain Avatar-only, or may it later resolve to other subject kinds?

Why this matters: It affects mention syntax, search, redirects, and reservation rules.

Current evidence:

- [app/models/handle.rb](app/models/handle.rb)
- [app/models/handle_assignment.rb](app/models/handle_assignment.rb)

What is unclear: Whether the lookup namespace is intended to be permanently Avatar-only.

Candidate options:

- Option A: Avatar-only permanently.
- Option B: Avatar-only for v1, expand later.
- Option C: shared lookup namespace from day one.

Recommended default: Option B.

Risk if unresolved: Handle conflicts with future group/account naming.

### Q06. Should old handles be reserved or reusable?

Question: When a handle is changed, does the old handle stay reserved forever, expire after
cooldown, or become reusable?

Why this matters: This decides the meaning of `HandleAssignment` and `cooldown_until`.

Current evidence:

- [app/models/handle.rb](app/models/handle.rb)
- [app/models/handle_assignment.rb](app/models/handle_assignment.rb)

What is unclear: Handle reuse policy is not explicit in code.

Candidate options:

- Option A: reserved forever.
- Option B: reusable after cooldown.
- Option C: reusable only by admins.

Recommended default: Option B, if a cooldown is required.

Risk if unresolved: Handle squatting or accidental hijack can occur.

### Q07. Is moniker history required to be immutable?

Question: Should moniker changes always create history rows, or can the current moniker be
overwritten?

Why this matters: It determines whether `AvatarMoniker` is authoritative or merely optional audit
data.

Current evidence:

- [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb)

What is unclear: The code shows temporal columns but not an explicit update policy.

Candidate options:

- Option A: immutable history rows only.
- Option B: current row plus overwrite.
- Option C: only a shadow audit trail.

Recommended default: Option A.

Risk if unresolved: Name changes will lose auditability.

### Q08. Does moniker need the same cooldown semantics as handle?

Question: Should `AvatarMoniker` have a cooldown comparable to `Handle.cooldown_until`?

Why this matters: The product decision requires handle and display/moniker cooldown parity, but the
schema does not show it.

Current evidence:

- [app/models/handle.rb](app/models/handle.rb)
- [app/models/avatar_moniker.rb](app/models/avatar_moniker.rb)

What is unclear: No cooldown column exists on `AvatarMoniker` in the inspected file.

Candidate options:

- Option A: add cooldown parity.
- Option B: moniker changes are immediate.
- Option C: cooldown only for handles.

Recommended default: Option A only if the product really needs symmetry.

Risk if unresolved: User-facing naming rules will diverge.

### Q09. Is `AvatarAssignment` legacy or still authoritative?

Question: Is `AvatarAssignment` the current authority model, or is it legacy compared with
`AvatarMembership`?

Why this matters: Both exist, and the boundary is not self-evident.

Current evidence:

- [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb)
- [app/models/avatar_membership.rb](app/models/avatar_membership.rb)

What is unclear: Whether the flat role table or the temporal membership table is the source of
truth.

Candidate options:

- Option A: assignment is authoritative.
- Option B: membership is authoritative.
- Option C: assignment for ownership, membership for access.

Recommended default: Option C.

Risk if unresolved: Duplicate authorization logic will appear.

### Q10. Should `AvatarMembership` represent access, ownership, or both?

Question: What exact lifecycle should `AvatarMembership` encode?

Why this matters: It carries `valid_from`, `valid_to`, `actor_id`, and `granted_by_actor_id`, but
the business meaning is not stated.

Current evidence:

- [app/models/avatar_membership.rb](app/models/avatar_membership.rb)

What is unclear: Whether the row is access only or a broader authority grant.

Candidate options:

- Option A: access only.
- Option B: ownership and access.
- Option C: generic grant history.

Recommended default: Option C.

Risk if unresolved: Role semantics will be impossible to explain later.

### Q11. What does `actor_id` mean in `AvatarMembership`?

Question: Who is `actor_id` on `AvatarMembership`?

Why this matters: It is the main ambiguity in the membership table.

Current evidence:

- [app/models/avatar_membership.rb](app/models/avatar_membership.rb)

What is unclear: The model does not declare an explicit association for the actor.

Candidate options:

- Option A: the subject account.
- Option B: the grant target.
- Option C: the grantor/editor.

Recommended default: Option C only if proven by surrounding code.

Risk if unresolved: Audit trails will be misread.

### Q12. What does `granted_by_actor_id` mean?

Question: Who grants an Avatar membership, and is that actor always an Avatar?

Why this matters: This is an authority boundary, not a simple metadata field.

Current evidence:

- [app/models/avatar_membership.rb](app/models/avatar_membership.rb)

What is unclear: The actor class is not fixed by the inspected file.

Candidate options:

- Option A: Avatar grantor.
- Option B: system grantor.
- Option C: any actor type.

Recommended default: Option C only if explicit code proves it.

Risk if unresolved: Permission grants may be attributed incorrectly.

### Q13. What does `assigned_by_actor_id` mean?

Question: Is `assigned_by_actor_id` an Avatar editor, a system account, or something else?

Why this matters: Handle history needs a trustworthy attribution model.

Current evidence:

- [app/models/handle_assignment.rb](app/models/handle_assignment.rb)

What is unclear: The code pins the association to `Avatar`, but the authority semantics are not
documented.

Candidate options:

- Option A: Avatar.
- Option B: system.
- Option C: either Avatar or system.

Recommended default: Option A for the current code.

Risk if unresolved: History records become ambiguous.

### Q14. Should handles be case-sensitive or case-insensitive?

Question: How should `Handle.handle` compare for uniqueness and lookup?

Why this matters: It affects collisions, normalization, and mention behavior.

Current evidence:

- [app/models/handle.rb](app/models/handle.rb)

What is unclear: Case sensitivity is not shown in the inspected validation or index comments.

Candidate options:

- Option A: case-sensitive.
- Option B: case-insensitive.
- Option C: normalize on write and compare normalized.

Recommended default: Option C.

Risk if unresolved: Users can create visually identical handles.

### Q15. Should handles allow only the current documented 10-character limit?

Question: Is the current handle-length target exactly 10 characters, or just a future product rule?

Why this matters: The repository evidence here does not prove the exact target limit.

Current evidence:

- [app/models/handle.rb](app/models/handle.rb)

What is unclear: The schema comment proves presence and uniqueness, but not the final UX rule.

Candidate options:

- Option A: exactly 10.
- Option B: longer current limit, 10 later.
- Option C: length should vary by surface.

Recommended default: Option B until a product rule is confirmed.

Risk if unresolved: Validation and UX will diverge.

### Q16. Should handle history be per-avatar or per-handle?

Question: Is `HandleAssignment` primarily avatar history or handle history?

Why this matters: It controls whether unassigned handles can be reused or retired.

Current evidence:

- [app/models/handle_assignment.rb](app/models/handle_assignment.rb)

What is unclear: The table stores both directions with temporal validity.

Candidate options:

- Option A: avatar history.
- Option B: handle history.
- Option C: both equally.

Recommended default: Option C.

Risk if unresolved: Future migrations will choose the wrong invariant.

### Q17. Should Avatar ownership be represented by `AvatarAssignment` or `AvatarOwnershipPeriod`?

Question: Which table is the true ownership ledger?

Why this matters: Two ownership-looking concepts exist today.

Current evidence:

- [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb)
- [app/models/avatar_ownership_period.rb](app/models/avatar_ownership_period.rb)

What is unclear: One is role-based, one is temporal, and neither is fully explained as ownership
source of truth.

Candidate options:

- Option A: assignment.
- Option B: ownership period.
- Option C: both with distinct semantics.

Recommended default: Option C with explicit boundary text.

Risk if unresolved: Ownership changes will be implemented twice.

### Q18. Should `Avatar` be creatable without a handle?

Question: Can Avatar exist before it has a current handle?

Why this matters: It affects creation flows and whether handle assignment is mandatory at bootstrap.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)

What is unclear: The bootstrap currently creates a handle and avatar together, but the schema
relationship is not a hard requirement in the model excerpt.

Candidate options:

- Option A: never without a handle.
- Option B: temporary unhandled avatar allowed.
- Option C: avatar created first, handle later.

Recommended default: Option A.

Risk if unresolved: Anonymous Avatar rows become reachable.

### Q19. Should `Avatar` always have exactly one current handle?

Question: Is exactly one current active handle mandatory for Avatar?

Why this matters: The schema currently has `active_handle_id` and temporal handle assignments.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/models/handle_assignment.rb](app/models/handle_assignment.rb)

What is unclear: Whether multiple historical handles are enough or one current handle must be
enforced everywhere.

Candidate options:

- Option A: exactly one current handle.
- Option B: zero or one.
- Option C: many concurrent handles.

Recommended default: Option A.

Risk if unresolved: Mention routing and current identity lookup become inconsistent.

### Q20. Should the selected context be stored on the session token or in a separate table?

Question: Should selection/switching continue writing to the session token, or should it move to a
dedicated table?

Why this matters: The current selector/switcher flow persists selected IDs on the token row.

Current evidence:

- [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb)
- [app/controllers/concerns/actor_support.rb](app/controllers/concerns/actor_support.rb)

What is unclear: Whether the session token remains the durable current-context store long term.

Candidate options:

- Option A: keep session-token storage.
- Option B: move to dedicated current-context table.
- Option C: hybrid with read model plus token projection.

Recommended default: Option C.

Risk if unresolved: The session row becomes a dumping ground for product state.

### Q21. Should `selected_avatar_public_id` be mandatory on app sessions?

Question: Should app sessions always carry `selected_avatar_public_id`, or can they stop at
account/organization selection?

Why this matters: `AcmeSelectableContext` only includes avatars for app when `requires_avatar` is
true.

Current evidence:

- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)
- [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb)

What is unclear: Whether app always requires Avatar in the active context tuple.

Candidate options:

- Option A: mandatory.
- Option B: optional depending on surface and feature gate.
- Option C: mandatory only after certain actions.

Recommended default: Option B.

Risk if unresolved: Session state will become over-constrained.

### Q22. Should com/org switchers remain stubs?

Question: Should the com and org switcher controllers stay stubbed, or should they mirror the app
switcher behavior now?

Why this matters: There is an implementation asymmetry in
[app/controllers/acme/com/switchers_controller.rb](app/controllers/acme/com/switchers_controller.rb)
and
[app/controllers/acme/org/switchers_controller.rb](app/controllers/acme/org/switchers_controller.rb).

Current evidence:

- [app/controllers/acme/com/switchers_controller.rb](app/controllers/acme/com/switchers_controller.rb)
- [app/controllers/acme/org/switchers_controller.rb](app/controllers/acme/org/switchers_controller.rb)

What is unclear: Whether the stubs are intentional placeholders or a gap.

Candidate options:

- Option A: keep stubs.
- Option B: implement parity.
- Option C: remove switchers from com/org.

Recommended default: Option A until product scope is confirmed.

Risk if unresolved: Users will get inconsistent context-switch UX.

### Q23. Should selector auto-bootstrap always create the Avatar row?

Question: Should selector bootstrap always create the Avatar row for app, and never for com/org?

Why this matters: The config already has `requires_avatar` toggles.

Current evidence:

- [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)
- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)

What is unclear: Whether the Avatar hook is permanent or only app-specific.

Candidate options:

- Option A: app only.
- Option B: app/com/org all eventually.
- Option C: no avatar bootstrap, create on demand.

Recommended default: Option A for now.

Risk if unresolved: Surface rules will diverge silently.

### Q24. What is the canonical account title field?

Question: Should `title` replace `moniker` on accounts, or should the two stay separate forever?

Why this matters: The bootstrap code already seeds both `moniker` and `title` for accounts in
[app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb).

Current evidence:

- [app/models/persona.rb](app/models/persona.rb)
- [app/models/agent.rb](app/models/agent.rb)
- [app/models/individual.rb](app/models/individual.rb)

What is unclear: Whether `moniker` is transitional or a lasting implementation term.

Candidate options:

- Option A: title replaces moniker.
- Option B: title and moniker coexist permanently.
- Option C: title is display-only.

Recommended default: Option A in product language, with moniker retained only as compatibility
storage until migration completes.

Risk if unresolved: The vocabulary conflict will spread into UI and docs.

### Q25. Should Organization use `title` or `name` long term?

Question: Should `Enterprise`/`Bureau`/`Company` keep `name`, or move to `title`?

Why this matters: The collective concern currently validates either `name` or `title` depending on
the model.

Current evidence:

- [app/models/enterprise.rb](app/models/enterprise.rb)
- [app/models/bureau.rb](app/models/bureau.rb)
- [app/models/company.rb](app/models/company.rb)
- [app/models/concerns/collective.rb](app/models/concerns/collective.rb)

What is unclear: Whether the names are transitional or final.

Candidate options:

- Option A: keep `name`.
- Option B: migrate to `title`.
- Option C: allow both indefinitely.

Recommended default: Option B if the product wants a single vocabulary.

Risk if unresolved: The collective layer will keep two naming systems alive.

### Q26. Should group models get their own `public_id` scheme?

Question: If group models are created, should they use a distinct public identifier format from
Avatar and Account/Organization records?

Why this matters: It affects URL stability and handle collision policy.

Current evidence:

- `public_id` is already a shared pattern across many subject models in
  [app/models/avatar.rb](app/models/avatar.rb) and the account/organization models.

What is unclear: Whether group ids must be visually distinct.

Candidate options:

- Option A: reuse the common `public_id` pattern.
- Option B: group-specific format.
- Option C: derive from parent Avatar or collective.

Recommended default: Option A.

Risk if unresolved: Public identifiers will become inconsistent across surfaces.

### Q27. Should group membership be many-to-many?

Question: Can one Avatar belong to multiple groups, and can one group contain multiple Avatars?

Why this matters: This changes the shape of the join table and all authorization checks.

Current evidence:

- No Group model or join table exists in the inspected files.

What is unclear: Cardinality is not represented yet.

Candidate options:

- Option A: many-to-many.
- Option B: one Avatar per group.
- Option C: group-as-collection with nested child groups.

Recommended default: Option A unless the product explicitly wants exclusivity.

Risk if unresolved: Group access will be impossible to reason about later.

### Q28. Should group membership confer visibility?

Question: Does a group membership make the Avatar visible to the group by default?

Why this matters: It determines whether groups are just collections or security boundaries.

Current evidence:

- No Group model exists.

What is unclear: Visibility semantics are absent.

Candidate options:

- Option A: yes.
- Option B: no, only explicit grants.
- Option C: visibility is separate from membership.

Recommended default: Option C.

Risk if unresolved: Membership and visibility will become inseparable.

### Q29. Should group membership confer representative authority?

Question: Can group membership authorize posting/representation, or is it read-only membership?

Why this matters: The product explicitly says representative authority is high-risk.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/models/avatar_membership.rb](app/models/avatar_membership.rb)

What is unclear: No group authority model exists.

Candidate options:

- Option A: yes.
- Option B: no.
- Option C: only special roles.

Recommended default: Option B.

Risk if unresolved: Posting rights will be granted too broadly.

### Q30. Should last-owner protection apply to groups?

Question: Do groups need last-owner or last-admin invariants from day one?

Why this matters: The product target explicitly calls this out.

Current evidence:

- Avatar owner role and current primary membership protections exist in
  [app/models/avatar.rb](app/models/avatar.rb) and
  [app/models/concerns/collective_membership.rb](app/models/concerns/collective_membership.rb).

What is unclear: There is no group implementation yet.

Candidate options:

- Option A: yes, from day one.
- Option B: no, add later.
- Option C: only for managed groups.

Recommended default: Option A.

Risk if unresolved: Groups can become orphaned.

### Q31. Should mentions store avatar_id or handle text?

Question: If mentions are added, should they store Avatar foreign keys or raw handle text?

Why this matters: This determines rename behavior and historical stability.

Current evidence:

- Handle history exists in [app/models/handle_assignment.rb](app/models/handle_assignment.rb).

What is unclear: There is no mention model today.

Candidate options:

- Option A: store avatar_id.
- Option B: store handle text.
- Option C: store both.

Recommended default: Option C.

Risk if unresolved: Handle changes will break mention history.

### Q32. Should deleted or suspended handles remain reserved?

Question: Do suspended or deleted Avatars keep their handles reserved?

Why this matters: It affects the meaning of cooldown and handle assignment history.

Current evidence:

- [app/models/handle.rb](app/models/handle.rb)
- [app/models/handle_assignment.rb](app/models/handle_assignment.rb)

What is unclear: Reservation-after-deletion policy is not in the inspected code.

Candidate options:

- Option A: yes.
- Option B: no.
- Option C: only for a retention window.

Recommended default: Option A.

Risk if unresolved: Handle reuse may expose old identities.

### Q33. Should `AvatarMembership` and `AvatarAssignment` remain both in the public docs?

Question: Should both model families be documented as active, or should one be marked legacy?

Why this matters: The architecture grill needs to reflect the real current code, not just the
desired code.

Current evidence:

- [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb)
- [app/models/avatar_membership.rb](app/models/avatar_membership.rb)

What is unclear: No accepted ADR declares one obsolete.

Candidate options:

- Option A: both active.
- Option B: assignment active, membership legacy.
- Option C: membership active, assignment legacy.

Recommended default: Option A until a deprecation decision exists.

Risk if unresolved: Future work will erase needed compatibility data.

### Q34. Should `member` be renamed before Avatar work advances?

Question: Does the `Member` layer need a rename or deprecation before new Avatar semantics are
added?

Why this matters: `Avatar` currently points at `Member`, and that relationship is structurally
confusing.

Current evidence:

- [app/models/member.rb](app/models/member.rb)
- [app/models/avatar.rb](app/models/avatar.rb)

What is unclear: Whether `Member` is a durable abstraction or a temporary adapter.

Candidate options:

- Option A: keep `Member`.
- Option B: rename later after Avatar ownership is fixed.
- Option C: replace with Account linking.

Recommended default: Option C, but only with a staged migration plan.

Risk if unresolved: The Avatar layer will remain bound to a legacy naming term.

### Q35. Should `collective` stay the selection term?

Question: Should the selector/switcher continue to use `collective_public_id`, or should it move to
explicit `organization_public_id` only?

Why this matters: The code already accepts both in some places.

Current evidence:

- [app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb)
- [app/controllers/acme/app/selectors_controller.rb](app/controllers/acme/app/selectors_controller.rb)

What is unclear: Whether collective is final product vocabulary or transitional internal language.

Candidate options:

- Option A: keep both with aliases.
- Option B: normalize to organization.
- Option C: normalize to collective.

Recommended default: Option A for compatibility, with one canonical term in docs.

Risk if unresolved: Public API and internal vocabularies will drift.

### Q36. Should selection be allowed without an avatar on app?

Question: Can app selection stop at account/organization/unit, or must every selected context
include an Avatar?

Why this matters: `AcmeSelectorSurfaceConfig` says app requires Avatar; com/org do not.

Current evidence:

- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)

What is unclear: Whether that app requirement is permanent or temporary.

Candidate options:

- Option A: Avatar required on app.
- Option B: Avatar optional on app.
- Option C: Avatar required only after certain actions.

Recommended default: Option A.

Risk if unresolved: The app context tuple will be inconsistent.

### Q37. Should com/org ever require Avatar?

Question: Could com or org later require Avatar in the selected context?

Why this matters: The current config says they do not.

Current evidence:

- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)

What is unclear: Whether the product wants future Avatar parity across surfaces.

Candidate options:

- Option A: never.
- Option B: maybe later.
- Option C: yes, for some actions.

Recommended default: Option A unless the product explicitly changes.

Risk if unresolved: Surface contracts will surprise users.

### Q38. Should Avatar be public-lookup only by `public_id` or also by handle?

Question: Should Avatar show pages and CRUD use `public_id` forever, or should handle also be
routable?

Why this matters: Route design and external links depend on it.

Current evidence:

- [app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb)
- [test/controllers/acme/app/avatars_controller_test.rb](test/controllers/acme/app/avatars_controller_test.rb)

What is unclear: There is no public Avatar handle route today.

Candidate options:

- Option A: public_id only.
- Option B: handle only.
- Option C: both with canonical redirect.

Recommended default: Option A.

Risk if unresolved: Links will become unstable after renames.

### Q39. Should Avatar ownership be organization-scoped, account-scoped, or both?

Question: Should ownership be tied to the collective, the account, or both?

Why this matters: The current code stores `owner_organization_id` and `client_id`.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)
- [app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)

What is unclear: Which one is the real authority boundary.

Candidate options:

- Option A: organization-scoped.
- Option B: account-scoped.
- Option C: both, with different meanings.

Recommended default: Option C only if the meanings are formally separated.

Risk if unresolved: Ownership rules will be double-encoded.

### Q40. Should `Chronicle.actor_id` ever be assumed to be Avatar?

Question: Can `Chronicle.actor_id` be treated as Avatar-specific in SNS docs or code?

Why this matters: It is a polymorphic column, not a fixed Avatar FK.

Current evidence:

- [app/models/chronicle.rb](app/models/chronicle.rb)

What is unclear: The polymorphic actor target varies by event source.

Candidate options:

- Option A: never assume Avatar.
- Option B: infer Avatar in SNS-only records.
- Option C: add a separate SNS audit table.

Recommended default: Option A.

Risk if unresolved: Audit data will be misinterpreted.

### Q41. Should Avatar social actions be policy-gated even before Group exists?

Question: Should follows, blocks, and mutes be behind explicit policy logic now, or remain
model-only for the moment?

Why this matters: The policy files are empty stubs.

Current evidence:

- [app/policies/avatar_follow_policy.rb](app/policies/avatar_follow_policy.rb)
- [app/policies/avatar_block_policy.rb](app/policies/avatar_block_policy.rb)
- [app/policies/avatar_mute_policy.rb](app/policies/avatar_mute_policy.rb)

What is unclear: There is no substantive authorization layer for these actions yet.

Candidate options:

- Option A: add policy gating now.
- Option B: defer until group posting exists.
- Option C: keep service-level checks only.

Recommended default: Option A.

Risk if unresolved: Social actions can bypass authorization architecture.

### Q42. Should app/org/com share a single SNS vocabulary doc?

Question: Should the three surfaces share one SNS vocabulary doc or three surface-specific docs?

Why this matters: The current data model is surface-specific, but the target SNS model is
product-wide.

Current evidence:

- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)

What is unclear: How much of the model should be universal versus surface-specific.

Candidate options:

- Option A: one shared doc.
- Option B: one doc plus surface appendices.
- Option C: separate docs by surface.

Recommended default: Option B.

Risk if unresolved: Vocabulary will diverge by surface.

### Q43. Should last-owner protection be enforced at the model layer or service layer?

Question: Where should last-owner / last-admin protection live?

Why this matters: It affects testability and whether the invariant can be bypassed by direct writes.

Current evidence:

- [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb)
- [app/models/concerns/collective_membership.rb](app/models/concerns/collective_membership.rb)

What is unclear: No explicit last-owner protection exists in the inspected code.

Candidate options:

- Option A: model validation.
- Option B: service guard.
- Option C: both.

Recommended default: Option C.

Risk if unresolved: Direct writes can orphan ownership.

### Q44. Should representative authority be temporal?

Question: Should representation be a current-only state or a temporal history with start/end
columns?

Why this matters: The product says representation is high-risk, which usually implies auditability.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)

What is unclear: The current schema does not encode temporal representation history.

Candidate options:

- Option A: current-only.
- Option B: temporal history.
- Option C: both current projection and history.

Recommended default: Option C.

Risk if unresolved: Representation changes will not be auditable.

### Q45. Should Avatar public profile be a distinct model?

Question: Should public profile data be kept on Avatar, or split into a separate profile model?

Why this matters: The current code has Avatar, moniker, handle, and image data all on one object.

Current evidence:

- [app/models/avatar.rb](app/models/avatar.rb)

What is unclear: Whether this should remain one aggregate.

Candidate options:

- Option A: keep on Avatar.
- Option B: split profile into a separate model.
- Option C: split only moniker/display state.

Recommended default: Option A.

Risk if unresolved: The profile surface will fragment.

### Q46. Should groups reuse collective membership tables?

Question: Can group membership reuse `PersonaMembership` / `AgentMembership` /
`IndividualMembership`, or does it need a new join type?

Why this matters: Reusing collective membership would blur the line between collective and group.

Current evidence:

- [app/services/acme_selector_surface_config.rb](app/services/acme_selector_surface_config.rb)
- [app/models/concerns/collective_membership.rb](app/models/concerns/collective_membership.rb)

What is unclear: Group semantics are not represented yet.

Candidate options:

- Option A: reuse collective membership.
- Option B: new group membership join.
- Option C: specialized group membership on Avatar.

Recommended default: Option B.

Risk if unresolved: Collective and group semantics will become inseparable.

### Q47. Should groups have units like collectives do?

Question: Do groups need nested units, or are they flat collections?

Why this matters: Units add a second hierarchy layer and another naming problem.

Current evidence:

- [app/models/enterprise_unit.rb](app/models/enterprise_unit.rb)
- [app/models/bureau_unit.rb](app/models/bureau_unit.rb)
- [app/models/company_unit.rb](app/models/company_unit.rb)

What is unclear: No group model or group unit model exists.

Candidate options:

- Option A: flat groups.
- Option B: groups with units.
- Option C: groups may contain subgroups later.

Recommended default: Option A.

Risk if unresolved: The group model will be overbuilt too early.

### Q48. Should the group nomenclature differ per surface?

Question: Why do the confirmed names call for `ClientGroup`, `VisitorGroup`, and `OperatorGroup`
instead of a generic `Group`?

Why this matters: The codebase already strongly prefers surface-specific model names.

Current evidence:

- [app/models/persona.rb](app/models/persona.rb)
- [app/models/agent.rb](app/models/agent.rb)
- [app/models/individual.rb](app/models/individual.rb)

What is unclear: Whether the user-facing product truly wants a generic common noun.

Candidate options:

- Option A: surface-specific models.
- Option B: one generic model.
- Option C: generic UI term with surface-specific storage.

Recommended default: Option A.

Risk if unresolved: Naming collisions will leak across surfaces.

### Q49. Should selector/bootstrap remain the source of truth for current context?

Question: Should `AcmeSelectorAuthority` and `AcmeSwitcherAuthority` remain the only current-context
writers?

Why this matters: Current context is already a shared runtime contract.

Current evidence:

- [app/services/acme_selector_authority.rb](app/services/acme_selector_authority.rb)
- [app/services/acme_switcher_authority.rb](app/services/acme_switcher_authority.rb)
- [app/controllers/concerns/actor_support.rb](app/controllers/concerns/actor_support.rb)

What is unclear: Whether other services are allowed to mutate selected IDs.

Candidate options:

- Option A: yes, only these writers.
- Option B: add dedicated helpers later.
- Option C: write through token abstractions only.

Recommended default: Option A.

Risk if unresolved: Context writes will become inconsistent.

### Q50. Should public profile, follows, blocks, and mutes stay Avatar-only until post/group arrives?

Question: Should all SNS interaction stay Avatar-only until a post/group model exists?

Why this matters: It prevents premature expansion of the public subject set.

Current evidence:

- [app/models/avatar_follow.rb](app/models/avatar_follow.rb)
- [app/models/avatar_block.rb](app/models/avatar_block.rb)
- [app/models/avatar_mute.rb](app/models/avatar_mute.rb)

What is unclear: There is no Post or Group model today.

Candidate options:

- Option A: Avatar-only until later.
- Option B: expand to accounts now.
- Option C: expand to groups now.

Recommended default: Option A.

Risk if unresolved: The SNS subject set will fragment before the core model is settled.

## Top Product / Architecture Decisions Still Required

Decision 01: Question: Should Avatar remain the only public SNS actor in v1? Choose one: A. Yes,
Avatar only. B. Avatar plus Account. C. Avatar plus Group. Recommended default: A. Why: The current
model and routes already center Avatar. Repository evidence:
[app/models/avatar.rb](app/models/avatar.rb),
[app/models/avatar_follow.rb](app/models/avatar_follow.rb) Risk of choosing wrong: The subject model
will split too early. Implementation affected:

- models: Avatar, follow/block/mute, handle history
- migrations: maybe none yet
- controllers: public Avatar routes
- routes: avatar/profile routes
- policies: AvatarPolicy family
- frontend: selectors and switchers
- tests: avatar and relation tests
- docs: this grill and architecture docs

Decision 02: Question: Should `Organization -> Account` be DB-enforced? Choose one: A. Yes. B. No,
service-only. C. Hybrid with service + projection. Recommended default: C. Why: Current code already
uses a service projection, but no direct FK exists. Repository evidence:
[app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb),
[app/services/acme_selector_bootstrap_authority.rb](app/services/acme_selector_bootstrap_authority.rb)
Risk of choosing wrong: Account ownership may drift. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 03: Question: Should `Avatar -> Account` be DB-enforced? Choose one: A. Yes. B. No,
service-only. C. Transitional Member-based ownership. Recommended default: A. Why: The current
`Avatar -> Member` path is the clearest structural mismatch. Repository evidence:
[app/models/avatar.rb](app/models/avatar.rb), [app/models/member.rb](app/models/member.rb) Risk of
choosing wrong: SNS actor ownership remains indirect. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 04: Question: Should `Group` be a new model family or a projection over collective models?
Choose one: A. New model family. B. Projection over collectives. C. Reuse collective models
directly. Recommended default: A. Why: The product vocabulary says Group should not be a generic
`Group`. Repository evidence: No Group model exists; collective model family exists in
[app/models/enterprise.rb](app/models/enterprise.rb), [app/models/bureau.rb](app/models/bureau.rb),
[app/models/company.rb](app/models/company.rb) Risk of choosing wrong: Collective and group
semantics will blur. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 05: Question: Should `AvatarAssignment` be retained as authority or collapsed into
`AvatarMembership`? Choose one: A. Retain both with a clear boundary. B. Collapse into membership
only. C. Collapse into assignment only. Recommended default: A. Why: Current code already uses both
layers. Repository evidence: [app/models/avatar_assignment.rb](app/models/avatar_assignment.rb),
[app/models/avatar_membership.rb](app/models/avatar_membership.rb) Risk of choosing wrong:
Authorization logic will duplicate or disappear. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 06: Question: Should handle history be immutable rows only? Choose one: A. Yes. B. No,
allow overwrite. C. Current row plus immutable history. Recommended default: A. Why:
`HandleAssignment` already looks temporal. Repository evidence:
[app/models/handle_assignment.rb](app/models/handle_assignment.rb) Risk of choosing wrong: Handle
changes will be hard to audit. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 07: Question: Should moniker history use a cooldown? Choose one: A. Yes. B. No. C. Only for
some surfaces. Recommended default: B or C, depending on product intent. Why: The schema currently
shows history but not cooldown. Repository evidence:
[app/models/avatar_moniker.rb](app/models/avatar_moniker.rb) Risk of choosing wrong: Display name
changes will feel inconsistent with handles. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 08: Question: Should `@handle` remain Avatar-only? Choose one: A. Yes. B. Expand later. C.
Shared namespace now. Recommended default: A. Why: Current code only supports Avatar handle
ownership. Repository evidence: [app/models/handle.rb](app/models/handle.rb),
[app/models/handle_assignment.rb](app/models/handle_assignment.rb) Risk of choosing wrong: Namespace
collisions. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 09: Question: Should representative authority be modeled separately from posting authority?
Choose one: A. Yes. B. No. C. Combine them for v1. Recommended default: A. Why: The product decision
already separates them. Repository evidence: [app/models/avatar.rb](app/models/avatar.rb) Risk of
choosing wrong: High-risk admin-like authority will be conflated with ordinary posting.
Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 10: Question: Should the current selector/switcher session-state projection stay on token
rows? Choose one: A. Yes. B. No, use a dedicated table. C. Hybrid projection. Recommended default:
C. Why: Current code already uses token rows, but a cleaner current-context model may be needed.
Repository evidence:
[app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb),
[app/controllers/concerns/actor_support.rb](app/controllers/concerns/actor_support.rb) Risk of
choosing wrong: Current context will be difficult to evolve. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 11: Question: Should group membership be many-to-many? Choose one: A. Yes. B. No, one
Avatar per group. C. Group tree only. Recommended default: A. Why: That is the least surprising
container model. Repository evidence: No group code yet; proposed target only. Risk of choosing
wrong: Group functionality will be too rigid. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 12: Question: Should groups inherit collective units? Choose one: A. Yes. B. No. C. Only
some groups. Recommended default: B. Why: Unit hierarchies already exist on collective models.
Repository evidence: [app/models/enterprise_unit.rb](app/models/enterprise_unit.rb),
[app/models/bureau_unit.rb](app/models/bureau_unit.rb),
[app/models/company_unit.rb](app/models/company_unit.rb) Risk of choosing wrong: The hierarchy will
become overcomplicated. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 13: Question: Should `display` remain the product term and `moniker` remain storage term?
Choose one: A. Yes. B. Rename storage to display. C. Keep moniker as product term. Recommended
default: A. Why: That matches the current code while preserving product vocabulary. Repository
evidence: [app/models/avatar.rb](app/models/avatar.rb),
[app/models/persona.rb](app/models/persona.rb) Risk of choosing wrong: Vocabulary drift.
Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 14: Question: Should last-owner protection apply to Avatar, Group, and collective
membership? Choose one: A. Yes. B. No. C. Only on some surfaces. Recommended default: A. Why: The
product explicitly requires it. Repository evidence: [app/models/avatar.rb](app/models/avatar.rb),
[app/models/concerns/collective_membership.rb](app/models/concerns/collective_membership.rb) Risk of
choosing wrong: Orphaned resources and broken recovery paths. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 15: Question: Should account titles stay ASCII alphanumeric length 1-10? Choose one: A.
Yes. B. Loosen later. C. Different per surface. Recommended default: A for the initial cut. Why:
That is already the active bootstrap plan direction. Repository evidence: GH issue #828 Risk of
choosing wrong: UI and validation drift. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 16: Question: Should the current `Member` layer remain visible in SNS docs? Choose one: A.
Yes, as an intermediate layer. B. No, hide it from SNS docs. C. Rename it now. Recommended default:
A. Why: It is part of the current graph. Repository evidence:
[app/models/member.rb](app/models/member.rb), [app/models/avatar.rb](app/models/avatar.rb) Risk of
choosing wrong: The real ownership path will be obscured. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 17: Question: Should `Chronicle` be the SNS audit model? Choose one: A. Yes. B. No,
dedicated SNS audit table. C. Both. Recommended default: C. Why: `Chronicle` exists, but `actor_id`
is polymorphic and not SNS-specific. Repository evidence:
[app/models/chronicle.rb](app/models/chronicle.rb) Risk of choosing wrong: Audit semantics will
remain ambiguous. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 18: Question: Should app/com/org selector params keep both `organization_*` and
`collective_*` names? Choose one: A. Yes. B. Normalize to organization only. C. Normalize to
collective only. Recommended default: A temporarily, with one canonical doc term. Why: The code
already accepts both. Repository evidence:
[app/controllers/acme/app/selectors_controller.rb](app/controllers/acme/app/selectors_controller.rb),
[app/services/acme_selectable_context.rb](app/services/acme_selectable_context.rb) Risk of choosing
wrong: Compatibility bugs during rollout. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 19: Question: Should app/org/com switchers be fully functional on all surfaces now? Choose
one: A. Yes. B. App only. C. Keep com/org stubs. Recommended default: C until their surface rules
are settled. Why: The current code is intentionally asymmetric. Repository evidence:
[app/controllers/acme/com/switchers_controller.rb](app/controllers/acme/com/switchers_controller.rb),
[app/controllers/acme/org/switchers_controller.rb](app/controllers/acme/org/switchers_controller.rb)
Risk of choosing wrong: Unfinished behavior leaks into user flows. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

Decision 20: Question: Should app Avatar CRUD remain public-id based in the route `:id` slot? Choose
one: A. Yes. B. Move to handle. C. Use a separate param name. Recommended default: A. Why: That is
the current controller contract. Repository evidence:
[app/controllers/acme/app/avatars_controller.rb](app/controllers/acme/app/avatars_controller.rb),
[test/controllers/acme/app/avatars_controller_test.rb](test/controllers/acme/app/avatars_controller_test.rb)
Risk of choosing wrong: Public URLs will change unnecessarily. Implementation affected:

- models:
- migrations:
- controllers:
- routes:
- policies:
- frontend:
- tests:
- docs:

## Recommended Implementation Sequence

1. Lock the vocabulary in docs and ADR cross-links.
2. Confirm or redesign the `Account -> Organization` invariant.
3. Confirm or redesign the `Avatar -> Account` invariant.
4. Clarify `actor_id` and `*_by_actor_id` semantics.
5. Clarify `AvatarAssignment` versus `AvatarMembership`.
6. Confirm handle and moniker history model.
7. Design cooldown policy.
8. Design last-admin/owner invariant.
9. Design `ClientGroup` / `VisitorGroup` / `OperatorGroup`.
10. Design the selector/switcher current-context read model.
11. Decide public Avatar handle routing.
12. Only then implement schema or controller changes in a separate task.

## Validation Notes

The following checks were attempted or performed during repository inspection:

- `pwd`
- `git status --short`
- `find . -maxdepth 3 -type f | sort | sed 's#^\\./##' | head -200`
- `rg -n "class .*Identity|class .*Account|class .*Organization|class .*Avatar|class .*Group|class .*Persona|class .*Enterprise|class .*Individual|class .*Company|class .*Agent|class .*Bureau|membership|assignment|grant|permission|role|represent|switcher|selector|handle|display|moniker|slug|public_id|public|code|profile|username|screen_name|actor_id|author_avatar_id|follow|block|mute" app config db docs plans test spec`
- `bin/rails routes | grep -Ei "account|organization|avatar|switcher|selector|membership|assignment|grant|group|profile|handle|follow|block|mute|post" || true`
- `bin/rails zeitwerk:check`
- `git diff --name-only`
- `git diff --stat`
- `git diff -- docs/architecture/sns-subject-resource-grill.md docs/index.md || true`

Results:

- `pwd` succeeded and confirmed the repository root.
- `git status --short` showed one unrelated untracked plan file.
- `find`/`rg` file inspection succeeded.
- `bin/rails routes` and `bin/rails zeitwerk:check` were blocked by the repository debugger hook,
  which tries to bind a UNIX debug socket in this sandbox and raises `Errno::EPERM`.
- No implementation files were modified for this task.

## Limitations

- Some claims are based on the inspected model and controller files only; I did not open every test
  or every supporting service.
- I did not verify any runtime behavior that requires a working Rails boot because `bin/rails` is
  blocked by the debugger hook in this environment.
- No Group or Post model exists in the inspected repository files, so group/post sections
  intentionally describe absence rather than implementation.
