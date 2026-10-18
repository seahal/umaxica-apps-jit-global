# Avatar Step 17 partial acceptance

Date: 2026-10-13 UTC. Work was performed on branch `feature` against full commit
`d0fa05fa1a6753b225323c8b7f2d8476ead3b87f`. The worktree already contained extensive unrelated
changes. This task changed only `app/operations/avatar_access_grants/issue_operation.rb` and
`test/services/avatar_access_grants_test.rb`; both were uncommitted during verification.

## Database boundary and observed state

Every Rails test command ran with `POSTGRESQL_ISOLATED_TEST_RUN_ID` unset and `PARALLEL_WORKERS=1`.
A read-only `bin/rails runner -e test` configuration inspection resolved the Avatar role to the
standard `test_avatar_db`; the other configured test roles also resolved to their regular
`test_*_db` names. No development, production, isolated-fleet or unknown database was used.

Read-only queries against `test_avatar_db` found the six draft migration versions absent and the
queried successor versions `20261010130000`, `20261010140000`, `20261010150000`, `20261010160000`,
`20261011220000`, `20261011220500`, `20261012130000` and `20261012130001` present.
`AvatarOwnershipCutover.exists?` was false. The current catalog contained 1 Avatar, 1 concrete
Enterprise ownership period, 4 Groups and 4 concrete Group ownership periods; it had no legacy
ownership periods, legacy Group periods or transfer reservations.

No database reset, migration, backfill, cutover, marker write or isolated-fleet script was run. The
standard Rails task `db:migrate:reset:avatar` is available, but would drop and recreate the existing
Avatar test database. The cutover marker is protected from ordinary deletion. Applying the marker or
rebuilding that database therefore remains gated on explicit risk and recovery-plan approval under
`AGENTS.md` and the database boundary recorded in `three.md` CHG-003.

## Writer and reader path ledger

The following paths were traced through application and task code. Marker-dependent behavior was
verified by the Rails tests in their normal test transactions; this does not claim a committed
cutover in the current catalog.

| Usable path                                                                                                                                                                                         | Read/write and authority before/after cutover                                                                                                                                                                                                                                                                                                                            | Coverage and result                                                                                                                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| APP creation: `Base::App::AvatarsController#create`, `BaseSelectorBootstrapAuthority#provision_avatar!`, and the `Avatar.create_with_owner` compatibility wrapper into `AvatarProvisioning::Create` | Requires owner `avatar.update` authority. Before the marker, the service writes the legacy period and its concrete Enterprise/Bureau mirror. After the marker, the source writes only the concrete period. The wrapper delegates to the same service; no in-repository caller of the wrapper was found.                                                                  | `test/services/avatar_provisioning/create_test.rb`, `test/models/avatar_test.rb`, `test/models/avatar_ownership_period_source_test.rb`, and the selector bootstrap tests ran without failures.                                                                          |
| APP and ORG Avatar reads/moniker updates, `Avatar#current_ownership_period`, `BaseSwitcherAuthority` through `AcmeSelectableContext`, and `AvatarPolicy` / `AvatarPermissionResolver`               | The ownership source selects legacy periods before cutover and concrete Enterprise/Bureau periods after it. Updates re-read and lock the selected source before writing a moniker.                                                                                                                                                                                       | `test/models/avatar_ownership_period_source_test.rb`, `test/resolvers/avatar_permission_resolver_test.rb`, and the APP/ORG Avatar controller tests ran without failures.                                                                                                |
| Group creation, update, archive and membership add/reorder/remove through the APP Groups and Group Avatar Membership controllers and `GroupManagement` / `GroupAvatarMemberships` operations        | The selected account (`account_surface`, `account_public_id`) is stored separately from owner-period facts. Group-period reads/writes select legacy rows before cutover and concrete rows after it. Membership changes revalidate Group and Avatar owners. Transfer acceptance removes memberships whose owner no longer matches and does not rewrite the Group account. | `test/services/group_management_test.rb`, `test/services/group_avatar_memberships_test.rb`, `test/policies/avatar_group_policy_test.rb`, `test/policies/group_avatar_membership_policy_test.rb`, and both ownership-period source tests ran without assertion failures. |
| APP/ORG legacy and Registry transfer request/accept/cancel endpoints                                                                                                                                | Legacy operations remain usable before cutover and explicitly refuse after it. Registry operations use concrete periods; acceptance stops writing legacy periods after the marker and preserves Group account context while removing stale memberships.                                                                                                                  | Operation tests and both APP/ORG controller test files ran without assertion failures. The complete HTTP authority matrix and independent-connection races remain open below.                                                                                           |
| Grant issue and resolution, plus Avatar/Group authorization                                                                                                                                         | Issuance checks current concrete owner authority. Resolution binds the recipient, capability and concrete ownership generation. Grants have no expiry column.                                                                                                                                                                                                            | `test/services/avatar_access_grants_test.rb`, `test/resolvers/avatar_permission_resolver_test.rb`, and Group membership tests ran without assertion failures; the required Grant matrix is PASS as detailed below.                                                      |
| Inventory, backfill, cutover and legacy-write barrier via `lib/tasks/avatar_backfill.rake` and the corresponding queries/operations                                                                 | Inventory is read-only; backfill writes only unambiguous concrete histories. The persistent marker switches reads/writes and activates the legacy-write barrier. No operational backfill or marker was applied to the current test database.                                                                                                                             | Inventory, transactional backfill/cutover-operation and barrier tests ran without assertion failures. Real committed rebuild, restore and cutover are BLOCKED.                                                                                                          |
| Maintenance: `RetentionPurgeJob#purge_avatars`, `AvatarPurgeDeferral`, legacy binding audit/backfill and `identity_graph_repair`                                                                    | Purge handling records an observable deferral and does not physically delete Avatar or ownership history. The binding backfill writes bindings, not ownership. Repair selection reads the current owner source.                                                                                                                                                          | Avatar retention, binding audit/backfill and relevant ownership-source tests ran without assertion failures. The independent-connection retention race is BLOCKED by the receipt guard.                                                                                 |

## Grant correction and verification

The required capability refusal test initially reproduced `I18n::MissingTranslationData` when an
unsupported transfer capability reached Active Record validation under the Japanese locale. The
service now validates the fixed capability set before opening its write transaction and raises an
explicit `ArgumentError`. This preserves the refusal contract, owner authority, stored records and
schema. Regression coverage now verifies:

- independent Persona Grants for two recipients on one Avatar, and one recipient on a second Avatar
  without membership in either owner organization;
- the exact `granted_at` instant and the nearest representable microsecond before it;
- denial of `avatar.update` and `avatar.transfer.request` when only `avatar.view` is granted;
- rejection of transfer capabilities at issue time and an Agent on an Enterprise period;
- absence of `expires_at` on both concrete Grant tables.

Existing regressions also cover revocation, closed periods, owner-only issue authority and the O1 →
O2 → O1 case where the first O1 Grant stays unusable while a fresh Grant on the new O1 period works.
The full scoped Grant matrix is PASS.

## Area results

| Area                            | Result                                                        | Remaining boundary                                                                                                                                                                                                                                                                                                                              |
| ------------------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AV-1 / AV-8 writers and readers | PASS for the traced local paths and simulated marker behavior | No committed cutover exists in the current test database; the commit-based consumer rehearsal belongs to Area 5.                                                                                                                                                                                                                                |
| AV-3 / AV-6 concurrency         | BLOCKED                                                       | Required independent-connection tests stop in `ParallelTestDatabaseCloner.verify_owned_worker_execution!` with `committed tests require run-owned worker receipts`. The user's standard-test/development-only rule does not authorize bypassing that guard or using the isolated fleet.                                                         |
| AV-5 HTTP authority             | BLOCKED                                                       | APP/ORG happy paths, selected-Avatar enforcement, Step-Up scopes, replay and pre-cutover transport refusal ran. The full refusal matrix on both surfaces—including alternate source-side canceller, invalid Principal, cross-surface, other-organization and other-Avatar cases—was not established.                                            |
| AV-7 Grants                     | PASS                                                          | The allowed N:M recipients, cross-family refusal, capability separation, issue-time boundary, revocation, closed/current generation and absence of Grant TTL are covered.                                                                                                                                                                       |
| MIG-2 / MIG-4 transition        | BLOCKED (static MIG-2 draft correspondence completed)         | Six drafts remain outside Rails migration discovery and their current test-catalog versions are absent. Rebuild/restore, committed Backfill, Cutover marker and post-cutover consumer writes were not run. The current test database has rows and the marker is immutable; resetting or applying cutover needs explicit risk/recovery approval. |

## Verification

- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 bin/rails test test/services/avatar_access_grants_test.rb test/resolvers/avatar_permission_resolver_test.rb test/operations/avatar_ownership_transfers_test.rb`:
  `40 runs, 203 assertions, 0 failures, 0 errors, 0 skips`.
- `env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 bin/rails test test/services/acme/selector_bootstrap_authority_test.rb test/services/acme/selector_authority_test.rb`:
  `12 runs, 88 assertions, 0 failures, 0 errors, 0 skips`.
- `mapfile -t avatar_tests < <(rg --files test -g '*avatar*_test.rb' -g '*group_avatar*_test.rb' | sort -u); env -u POSTGRESQL_ISOLATED_TEST_RUN_ID PARALLEL_WORKERS=1 bin/rails test "${avatar_tests[@]}" test/services/group_management_test.rb`:
  `380 runs, 1,524 assertions, 0 failures, 14 errors, 0 skips`. All 14 errors came from the
  run-owned worker receipt guard before the corresponding committed-test body ran; they are not
  passing concurrency evidence.
- `bundle exec rubocop app/operations/avatar_access_grants/issue_operation.rb test/services/avatar_access_grants_test.rb`:
  no offenses.
- `git diff --check -- app/operations/avatar_access_grants/issue_operation.rb test/services/avatar_access_grants_test.rb`:
  passed.

AT-073 closure and Step 17 remain BLOCKED because Areas 2, 3 and 5 are open. Steps 12–16 remain
dependency-gated by the earlier blocked steps and the unfinished Palm/Tech work; Step 18 must wait
for the last functional change. The full-suite gate at Step 19 and Strict Loading Step 20 were not
run.
