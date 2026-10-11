# Avatar committed writer and cleanup preparation

HEAD: `d74e674d21e21207af02a086a9abbfe0104ab436`, feature. Application, test, migration, schema and
environment-adapter work is uncommitted alongside unrelated source-policy/OTP documentation.
Documentation persistence is not a complete implementation snapshot. Scope: AV-1/AV-2/AV-3, MIG-3,
P7 preparation. No production, shared destructive operation, remote or CI execution.

Three existing committed concurrency cases now require a current concrete owner: moniker renames,
pending transfer requests, and retention deferrals. Genuine Red in the seven-file affected
collection: 58 runs, 236 assertions, three failures, zero errors/skips, 3.045398 seconds, four
workers. Each expected one current Enterprise period and observed zero.

Their setup now explicitly resolves/creates an Enterprise and inserts Avatar plus its concrete
period in one Avatar-DB transaction with valid_from derived from Avatar creation. The registry
same-key case likewise creates Avatar and source period atomically and uses the actual Enterprise
public ID. No new business helper, implicit owner, test-aware application branch or organization
access Grant was introduced. Committed Avatar/history/operation rows remain for whole-worker cleanup
rather than row deletion. This does not yet implement the production creation guard.

The existing ParallelTestDatabaseCloner now verifies live run-owned parent and worker creation
receipts before committed cases write. No receipt, a mixed/serial target or non-test admission
refuses, with no shared fallback or skip. Rollback-only cases do not require this committed-case
admission. A direct two-worker construction runner verified positive admission and three negative
values, restored the original parent configurations and cleaned its forty objects, exit 0. The
non-test value was exercised inside this already test-configured runner, not a production boot.

Initial Green: 58 runs, 254 assertions, zero failures/errors/skips, 2.706443 seconds. Subsequent
local verification exposed four provisioning errors (58 runs, 234 assertions, zero failures/four
errors, 2.781552 seconds): retained cross-DB memberships could alias fixture-rebuilt principal IDs
and BootstrapAuthority received a nil collective. New feature work stopped. Scoped cleanup of
mutable PersonaMembership and EnterpriseUnit/closure rows restores test independence while retaining
Avatar, organization and ownership-history records. No product selector fallback or expectation
weakening was added.

The same failing seed (22353) then passed product tests: 58 runs, 254 assertions, zero
failures/errors/skips, 2.723439 seconds. However, the generic exit cleanup refused remaining active
connections. Its error printed despite process status 0; that run was not accepted as a successful
resource gate. Read-only catalogs subsequently found forty inactive worker objects with exact
matching creation receipts for workers 2/3. Only those two verified receipts were reconciled through
the existing cleanup entry point; parent objects/roles remained intact.

Actual installed Minitest 6.0.6 provides public after_run before its final exit status. Its run
shuts down the parallel executor before reporting. Suite cleanup now registers there, guarded by
parent PID; standalone construction retains exit cleanup. Final local recovery at seed 22353: 58
runs, 254 assertions, zero failures/errors/skips, 2.706054 seconds, exit 0 with no cleanup error.
Post-exit read-only checks found all eighty worker names absent and twenty parent OID/owner/comment
rows unchanged. No connection was terminated or unknown object force-dropped.

Commands used the verified 20261010p3d2 manifest, primary host, complete preparation list, test
environment and four workers (two for the direct construction probe), without printing secrets.

- Local collection:
  `bundle exec rails test test/operations/avatar_moniker_writer_operation_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb test/jobs/avatar_retention_purge_test.rb test/models/avatar_transfer_reservation_test.rb test/models/avatar_test.rb test/models/avatar_concrete_ownership_period_test.rb test/services/avatar_provisioning/create_test.rb`.
  Recovery appended `--seed 22353`; all outcomes above refer to actual runs.
- `bundle exec rails runner /tmp/avatar-owned-worker-admission-20261011.rb`: direct infrastructure
  admission checks, exit 0; temporary session script, not a durable test or new runner.
- `bundle exec ruby /tmp/worker-active-catalog-20261011.rb`: read-only remaining identity/connection
  checks, exit 0; no raw queries, personal data or tokens recorded.
- `bundle exec rails runner` with the exact two matching worker receipt paths: existing strict
  cleanup entry point, exit 0. No adoption by name alone or cluster-role deletion.
- `bundle exec ruby /tmp/isolated-clone-cleanup-catalog-20261011.rb`: read-only post-exit identity
  checks, exit 0.
- `bundle exec rubocop test/support/parallel_test_database_cloner.rb test/operations/avatar_moniker_writer_operation_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb test/jobs/avatar_retention_purge_test.rb test/models/avatar_transfer_reservation_test.rb`:
  five files, zero offenses. `git diff --check` passed.

The first full Gate 3 recovery found a further common test-isolation regression: 15,036 runs,
127,475 assertions, eight failures/four errors, zero skips, 319.478688 seconds, exit 1. Retained
synthetic ClientPersona/ClientIdentity rows contaminated later whole-family cutover inventories and
reused fixture principal IDs. All eighty workers were removed and parent catalog identities
preserved. The existing scoped synthetic-principal teardown was restored; Avatar and concrete
ownership history still remain until whole-worker disposal. The affected seven-file
cutover/concurrency collection passed: 50 runs, 212 assertions, zero failures/errors/ skips,
2.106088 seconds, exit 0. No cutover expectations or production rules were weakened.

`bun run test` before that recovery passed 99 files, 1,140 tests, 13.64 seconds, exit 0. The
restarted Vitest passed 99 files/1,140 tests in 13.54 seconds, exit 0. Rails completed 15,036
runs/127,509 assertions with one failure, zero errors/skips in 333.301128 seconds, final process
exit 1. All prior twelve cutover failures/errors were absent. The remaining failure is
Security::AcmeRenameInventoryTest at test/unit/security/acme_rename_inventory_test.rb:52: another
task's untracked adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md:27 says "Apex-scoped",
violating the existing rename inventory. This document is not owned by this slice and was preserved;
permission for the minimal wording correction was requested. The gate is not Green.

After terminal exit, the read-only catalog check passed: all eighty planned worker names absent,
twenty parent OID/owner/comment identities preserved. An earlier catalog check during live cleanup
reported remaining workers; that was not a terminal cleanup result. No next feature may start until
the naming failure is resolved and both full suites pass against the resulting source.

Document formatting, scoped repository-knowledge validation (8 Skills/adapters, 69 documents, 1
evidence record), and git diff --check passed. Scoped RuboCop after the final principal-cleanup
correction inspected one file with zero offenses. These are not independent acceptance.

Ownerless creation rejection, full ownership concurrency at RC/RR/SERIALIZABLE, legacy cutover and
full nine.md acceptance remain incomplete. This preparation is not independent acceptance.
