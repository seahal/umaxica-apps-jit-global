# Avatar ownership consumer ledger and post-marker regression coverage

- Date: 2026-10-14.
- Git commit: `aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`.
- Worktree: dirty; 855 changed or untracked entries were present when the final focused verification
  started. The uncommitted Avatar test changes described here affected the result.
- Model: Codex, GPT-6. Reasoning effort was not exposed to the agent in this session.
- Frozen plan hashes: `one.md` `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`;
  `two.md` `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.

This ledger follows the usable Avatar/Group code paths found by tracing the ownership-source
selectors through their service, policy, controller, transfer, maintenance and Rake callers. The
marker-dependent behavior is covered below with standard `test` database tests that establish the
marker inside a transaction and roll the synthetic state back. This verifies local branching and
consumer behavior; it does not establish an operational cutover on any persistent database.

| Path and method | Ownership data read or written | Before marker | After marker | Coverage and result |
| --- | --- | --- | --- | --- |
| `AvatarProvisioning::Create#call` / `#create_ownership_period!` in `app/services/avatar_provisioning/create.rb` | Creates first owner period and account binding. | Writes through `AvatarOwnershipPeriodSource`; that writes the legacy period and the concrete Enterprise/Bureau mirror. | Writes the concrete period only. | `test/services/avatar_provisioning/create_test.rb` covers pre-marker creation and the added post-marker case asserts no legacy row, one current concrete row, and `created_at` as the start. PASS in focused suite. |
| `BaseSelectorBootstrapAuthority#provision_avatar!` in `app/services/base_selector_bootstrap_authority.rb` | Looks up an existing Avatar by selected owner; creates through provisioning if absent. | `relation_for` scopes by current legacy owner. | `relation_for` scopes by current concrete owner. | `test/services/acme/selector_bootstrap_authority_test.rb` now bootstraps a new APP account after marker and asserts a concrete-only initial owner; selector/bootstrap and provisioning tests also pass. PASS in focused suite. |
| `AcmeSelectableContext#avatars_for`; `BaseSelectorAuthority#selectable_candidates`; `BaseSwitcherAuthority#available_avatars` / `#find_avatar` | Lists or resolves selectable Avatars by surface owner and permission. | Uses the source's legacy-owner relation. | Uses only the concrete owner relation. | Selector and APP/ORG switcher controller tests plus new `test/services/base_switcher_authority_test.rb` post-marker case. PASS in focused suite; no real browser session was exercised. |
| `Avatar#current_ownership_period`; `AvatarOwnershipPeriodSource.current_for`, `.all_for`, `.relation_for`, `.create!` in `app/models/` | Supplies current/history owner, owner-scoped relation, or initial write. | Legacy period is authoritative; create also writes the concrete mirror. | Enterprise/Bureau periods are authoritative; no legacy fallback or legacy write. | `test/models/avatar_ownership_period_source_test.rb`, pre-marker transfer/provisioning tests, post-marker policy/provisioning/transfer tests. PASS for tested paths. |
| APP Avatar HTTP: `Base::App::AvatarsController#index`, `#show`, `#create`, `#update` | Policy/switcher read owner; create provisions; update locks and rechecks owner before a moniker write. | Source resolves legacy owner. | Source resolves concrete owner. | `test/controllers/base/app/avatars_controller_test.rb` plus source, policy and provisioning tests. The post-marker HTTP update test asserts a concrete Enterprise owner and no new legacy ownership row. PASS in the focused suite. |
| ORG Avatar HTTP: `Base::Org::AvatarsController#show`, `#edit`, `#update`, `#selected_avatar` | Switcher resolves the selected Avatar; update locks and rechecks owner before a moniker write. | Source resolves legacy owner. | Source resolves concrete owner. | `test/controllers/base/org/avatars_controller_test.rb` plus source, policy and switcher tests. The post-marker selected-Avatar update test asserts a concrete Bureau owner, unchanged legacy history and retained selected Avatar. PASS in the focused suite. |
| `AvatarGroup#ownership_periods` / `#current_ownership_period`; `AvatarGroupOwnershipPeriodSource.model`, `.all_for`, `.current_for`, `.create!` | Supplies Group ownership history, current owner and first-period writer. Group `account_surface/account_public_id` remains separate. | Legacy Group period is authoritative. | Concrete Group period is authoritative; no legacy fallback. | `test/models/avatar_group_ownership_period_source_test.rb` exercises before/after reads and post-marker create; new Group policy/management cases assert independent account context. PASS in focused suite. |
| `AvatarPolicy` relation scope, `#show?`, `#update?` | Reads Avatar owner and scopes visible Avatars by current owner and selected collective. | Uses legacy owner through the source. | Uses concrete owner through the source. | `test/policies/avatar_policy_test.rb` now includes a post-marker public-policy and relation-scope case. PASS in focused suite. |
| `AvatarGroupPolicy` relation scope, `#show?`, `#update?`, `#destroy?` | Reads Group owner and selected account context; does not derive account identity from owner. | Current owner comes from legacy Group period. | Current owner comes from concrete Group period. | `test/policies/avatar_group_policy_test.rb` now asserts post-marker scope, show authority and distinct account/owner identities. PASS in focused suite. |
| `GroupManagement::Create#call`, `GroupManagement::Update#call`, `GroupManagement::Archive#call` | Create writes Group plus first ownership period; update/archive lock and recheck owner, then change only Group metadata/state. | Period writer uses legacy source and the concrete mirror. | Period writer uses concrete source only; update/archive resolve concrete owner and preserve account context. | `test/services/group_management_test.rb` now covers create/update/archive under a transactional marker. PASS in focused suite. |
| `GroupAvatarMembershipPolicy` and `Base::App::GroupAvatarMembershipsController#create`, `#update`, `#destroy` | Policy and controller authorize selected Group/Avatar; controller delegates to membership operations. | Model accessors resolve legacy periods. | Model accessors resolve concrete periods. Account context is not rewritten. | `test/policies/group_avatar_membership_policy_test.rb` has a post-marker policy case. `test/services/group_avatar_memberships_test.rb` covers post-marker attach/reorder/detach. The existing `test/controllers/base/app/groups_controller_test.rb` now also exercises post-marker HTTP create, reorder and detach, verifies concrete owners/account context, and rolls the marker and synthetic owner period back. PASS in the focused suite. |
| `GroupAvatarMemberships::Attach#call`, `#Reorder#call`, `#Detach#call` | Reads and locks current Group/Avatar owners; writes membership state/position only. | Locks legacy owners. | Locks concrete owners; attach/reorder require same current owner; detach remains group-owner-authorized. | Existing service cases plus the added post-marker sequence in `test/services/group_avatar_memberships_test.rb`. PASS in focused suite. |
| `AvatarPermissionResolver#call` / `#resolve_avatar_grant`; `AvatarAccessGrantResolver#call` | Checks owner membership or a capability grant tied to the Avatar's current concrete generation and subject. | Grant resolution is concrete-period-based and requires that concrete current period; it does not infer from legacy-only history. | Same concrete-generation authority; closed or stale periods do not authorize. | `test/resolvers/avatar_permission_resolver_test.rb`, `test/services/avatar_access_grants_test.rb`, and Group membership policy/service tests. PASS for executed grant cases, including refusal of `avatar.grant.manage` and all `avatar.transfer.*` permissions from a view Grant. |
| `AvatarAccessGrants::IssueOperation#call` | Locks a current concrete Enterprise/Bureau period and writes a Persona/Agent grant with capability and issuer facts. | Grant storage/issuance is already concrete-period-based; a legacy-only period is not accepted. | Same concrete-period write; old generations remain ineffective. | Grant tests cover APP Persona and ORG Agent issuance, multiple recipients/Avatars, capability refusal, closed period, revocation and grant-time boundary. A non-owner Grant recipient is refused when trying to issue another grant; transfer tests cover return to O1 without reviving its old Grant. PASS for executed cases; not a claim that every product combination was run. |
| Legacy `AvatarOwnershipTransfers::RequestOperation#call`, `AcceptOperation#call`, `CancelOperation#call`; APP and ORG transfer controllers | Uses the selected owner source before transition; accepts update period history and membership consequences. | Keyless legacy flow is available against legacy ownership. | Legacy operations explicitly refuse instead of writing the barrier-protected tables. | `test/operations/avatar_ownership_transfers_test.rb` and both transfer controller tests. PASS for selected sequential and HTTP cases; independent committed races remain blocked. |
| Registry `RegistryRequestOperation#call`, `RegistryAcceptOperation#call`, `RegistryCancelOperation#call`; APP and ORG transfer controllers | Records concrete source generation; accept closes/opens concrete periods, updates reservation, and removes mismatched Group memberships. | Validates legacy and concrete owner agreement; accept mirrors legacy and concrete periods. | Uses concrete source only; no legacy-period write. | Transfer operation/controller tests include a post-marker accept asserting no additional legacy row, plus Group account-context and transfer-membership cases. PASS for selected paths; full lock-race matrix remains blocked. |
| `AvatarOwnershipTransitionInventoryQuery#call` and `AvatarGroupOwnershipTransitionInventoryQuery#call` | Read-only comparison of legacy and concrete chains, classifying conflicts, missing copies and readiness. | Reads both stores. | Reads both stores; inventory does not change the authority marker or choose an owner. | Both query test files passed in the focused suite. |
| `AvatarConcreteOwnershipBackfillOperation#call` / `AvatarGroupConcreteOwnershipBackfillOperation#call` | Reads legacy history and writes only unambiguous concrete copies in bounded apply mode. | Intended pre-cutover maintenance path. | Must not be used to restore legacy authority; source readers already use concrete periods. | Both operation test files passed in the focused suite. No backfill task was executed against a persistent database. |
| `AvatarOwnershipCutoverOperation#call`, marker barrier migrations and `lib/tasks/avatar_backfill.rake` tasks | Inventory both stores; if ready and explicitly quiesced, write singleton marker. Barrier rejects legacy period/transfer/Group-period writes after marker. Rake tasks expose inventory, backfill and cutover operations. | Marker absent; legacy source and writes remain permitted. | Marker present; concrete sources govern and legacy writes are refused. | Cutover operation and barrier tests passed, including simulated marker creation and legacy-write refusal. The Rake tasks were source-inspected only. Operational cutover/backfill is BLOCKED under the current shared-database-only instruction; no task, migration or cutover was run. |
| `RetentionPurgeJob#purge_avatars`; `AvatarPurgeDeferral.record!` | Checks concrete ownership history and records a durable deferral rather than deleting ownership-backed Avatars. | Same concrete-history check; new creation maintains a concrete mirror before cutover. | Same concrete-history check. | `test/jobs/retention_purge_job_test.rb` passed, including the Avatar deferral case. `test/jobs/avatar_retention_purge_test.rb` committed/concurrent cases remain receipt-gated and were not run in this focused command. |
| `AvatarOwnershipTransfers::Operation#remove_group_memberships_with_different_owner!` | Reads Group owner periods and marks memberships removed when the destination owner differs; leaves Group account context intact. | Reads the legacy Group owner source. | Reads the concrete Group owner source. | `test/operations/avatar_ownership_transfers_test.rb` now accepts a post-marker transfer with both a target-owned and former-owner Group membership; it keeps the matching membership, removes the mismatched one and preserves both Groups' account contexts. PASS in the focused suite. |

The source census also checked `app/jobs`, `lib/tasks` and callers of
`AvatarOwnershipTransfers::ExpireReservationOperation`. No production job or task caller of that
operation was found; the operation changes reservation lifecycle, not owner-period history. It is
not an additional active ownership writer in the inspected application graph.

## Verification

The following focused selection ran with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset, `RAILS_ENV=test`
and `PARALLEL_WORKERS=1`. Rails reported the repository's standard `test_*` database manifest and
migration scope. Result: **248 runs, 1,336 assertions, 0 failures, 0 errors, 0 skips**.

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/base/app/avatar_ownership_transfers_controller_test.rb \
  test/controllers/base/org/avatar_ownership_transfers_controller_test.rb \
  test/controllers/base/app/avatars_controller_test.rb \
  test/controllers/base/org/avatars_controller_test.rb \
  test/controllers/base/app/groups_controller_test.rb \
  test/controllers/base/app/switchers_controller_test.rb \
  test/controllers/base/org/switcher_controller_test.rb \
  test/jobs/retention_purge_job_test.rb \
  test/models/avatar_group_concrete_ownership_period_test.rb \
  test/models/avatar_group_ownership_period_source_test.rb \
  test/models/avatar_ownership_cutover_barrier_test.rb \
  test/models/avatar_ownership_period_source_test.rb \
  test/operations/avatar_concrete_ownership_backfill_operation_test.rb \
  test/operations/avatar_group_concrete_ownership_backfill_operation_test.rb \
  test/operations/avatar_ownership_cutover_operation_test.rb \
  test/operations/avatar_ownership_transfers_test.rb \
  test/operations/avatar_registry_transfer_failure_test.rb \
  test/policies/avatar_group_policy_test.rb \
  test/policies/avatar_policy_test.rb \
  test/policies/group_avatar_membership_policy_test.rb \
  test/queries/avatar_group_ownership_transition_inventory_query_test.rb \
  test/queries/avatar_ownership_transition_inventory_query_test.rb \
  test/resolvers/avatar_permission_resolver_test.rb \
  test/services/acme/selector_authority_test.rb \
  test/services/acme/selector_bootstrap_authority_test.rb \
  test/services/avatar_access_grants_test.rb \
  test/services/avatar_backfill/audit_legacy_client_bindings_test.rb \
  test/services/avatar_backfill/backfill_legacy_client_bindings_test.rb \
  test/services/avatar_provisioning/create_test.rb \
  test/services/base_switcher_authority_test.rb \
  test/services/group_avatar_membership_authorization_test.rb \
  test/services/group_avatar_memberships_test.rb \
  test/services/group_management_test.rb
```

`bundle exec rubocop` on the 15 changed Ruby test files passed with no offenses. `git diff --check`
passed. The post-marker Group membership HTTP test passed alone with **11 runs, 71 assertions**; the
APP/ORG Avatar controller files passed together with **21 runs, 160 assertions**. Both standalone
and combined results had no failures, errors or skips. A read-only test-environment runner after the
focused selection observed `avatar_cutover_marker: false`, 8 concrete Group-owner periods, 1
Enterprise Avatar-owner period and 0 Bureau Avatar-owner periods. The marker is absent; the counts
are recorded as observed without comparison to a pre-run snapshot or cleanup.

```sh
env -u POSTGRESQL_ISOLATED_TEST_RUN_ID RAILS_ENV=test bin/rails runner \
  'puts({ avatar_cutover_marker: AvatarOwnershipCutover.established?, app_group_owner_periods: AvatarGroupConcreteOwnershipPeriod.count, enterprise_avatar_owner_periods: AvatarEnterpriseOwnershipPeriod.count, bureau_avatar_owner_periods: AvatarBureauOwnershipPeriod.count }.inspect)'
```

## Disposition and limits

- AT-070 now has a source-level ledger and local regression evidence for the listed consumers;
  operational pre/post-cutover behavior for every consumer remains **BLOCKED** because the user
  authorized only the shared Rails `development` and `test` databases and no real operational
  cutover may be run on them.
- AV-3 / AV-6 independent committed-history races remain **BLOCKED** by the run-owned worker-receipt
  guard. Do not bypass the guard or run those non-transactional cases against the shared test DB.
- MIG-2 / MIG-4 remain **BLOCKED** for persistent migration/rebuild/restore/cutover rehearsal.
- The latest full Rails result remains 15,243 runs, 128,890 assertions, 0 failures, 14 worker-receipt
  errors and 0 skips; see
  [`C7P2`](2026-10-14-step20-post-fix-suite-C7P2.md). This focused selection does not replace the
  full suite or the committed-history gate.
- No isolated fleet, database reset, explicit migration task, persistent marker, cutover, production target,
  manual cleanup or commit was used. The current synthetic Groups retained from the earlier run
  were not changed.
