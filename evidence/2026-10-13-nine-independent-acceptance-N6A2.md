# Independent acceptance of nine.md

Date: 2026-10-13. Repository: `/home/global/workspace`. Branch: `feature`. Full code HEAD:
`4828aeedd141b54163236672890799b9b01128c2`. The tracked/untracked worktree was clean at the start.
Existing ignored runtime assets and the isolated database manifest were preserved. Application,
tests, migrations, configuration and acceptance definitions were not edited. This evidence file is
the only intended repository change. No commit, external publication, production operation or
retained-data cutover was performed.

## Decision

**The integrated delivery is not accepted as complete.** All five domains have substantial
executable implementation, and the current regression results support that progress. They do not
establish all requirements. A direct counterexample violates ID-4, the required JavaScript coverage
gate fails, and telemetry flushing has a reproducible runtime error. Complete route/purpose
coverage, full migration/recovery campaigns and host collector/mount acceptance remain unverified. A
percentage of implementation completeness would be misleading: the requirements have different
scope, and passing existing tests is not a denominator for all required behavior.

This investigation follows `docs/checklists/integrated-stack.md` and its five domain owners plus
`specs/integrated-stack-delivery/acceptance.md`. Historical implementation reports were used to
locate checks, never substituted for current execution. This is a current acceptance assessment with
explicitly bounded probes, not a claim to have exhausted every requirement cross-product.

## Execution and safety

The initial sandboxed database preflight failed at DNS resolution. Its approval request was
interrupted; after the user resumed with unrestricted execution, the same preflight succeeded.
`Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!` verified 20 disposable parent databases
against `tmp/acceptance-isolated-20261010p8b-primary.json`. No shared database was selected.
Existing parallel test infrastructure created and verified its own worker catalogs and real-COMMIT
receipts. The suite's migration preparation was inspected: it uses verified database names and
normal migrations, not a schema-reset command. Committed Avatar cases refuse unowned worker targets.
No parent fleet rebuild, role deletion, trigger disabling or integrity bypass was requested.

Rails commands used:

```sh
RAILS_ENV=test PARALLEL_WORKERS=4 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
bundle exec ruby -rjson -e '
  ENV["POSTGRESQL_TEST_PREPARE_DATABASES"] =
    JSON.parse(File.read(ENV.fetch("POSTGRESQL_ISOLATED_TEST_MANIFEST")))
      .fetch("databases").map { |entry| entry.fetch("name") }.join(",")
  exec("bin/rails", "test", *ARGV)
' [selected test paths, or none for the full suite]
```

The focused selection was:

```text
test/models/concerns/public_id_test.rb
test/models/public_id_capacity_contract_test.rb
test/models/avatar_concrete_ownership_period_test.rb
test/operations/avatar_ownership_transfers_test.rb
test/operations/avatar_ownership_transfers_concurrency_test.rb
test/models/ceremony_owned_otp_concurrency_test.rb
test/models/live_identifier_creation_concurrency_test.rb
test/operations/dead_identifier_purge_test.rb
test/integration/sign_up_phase_regression_app_test.rb
test/integration/root_login_establishment_flow_test.rb
test/unit/security/filter_parameter_logging_test.rb
test/unit/security/action_mailer_logging_policy_test.rb
test/unit/security/opentelemetry_initializer_test.rb
```

| Check                                                            | Current result                                                                                                                                     |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Focused Rails selection                                          | PASS: 171 runs, 1,521 assertions, zero failures/errors/skips; seed 53093                                                                           |
| Full Rails suite                                                 | PASS: 15,204 runs, 128,528 assertions, zero failures/errors/skips; 333.49 seconds, process exit 0                                                  |
| `bun run test`                                                   | PASS: 99 files, 1,140 tests                                                                                                                        |
| `bun run test:coverage`                                          | FAIL: 99 files/1,140 tests pass, but functions 98.48% and branches 97.21% are below the configured 99% thresholds; statements 99.21%, lines 99.20% |
| `bun run check`                                                  | PASS, including format, lint, typecheck coverage, typecheck, deadcode, OpenAPI lint and bundle comparison                                          |
| `bin/rubocop`                                                    | PASS: 5,380 files, no offenses                                                                                                                     |
| `bundle exec erb_lint --lint-all`                                | PASS: 4,391 files, no errors                                                                                                                       |
| `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | PASS: zero errors and zero security warnings                                                                                                       |
| `scripts/check-repository-knowledge`                             | PASS before evidence creation: 8 Skills/adapters, 67 documents, zero evidence records in its selected scope                                        |
| `git diff --check`                                               | PASS before evidence creation                                                                                                                      |
| `bin/rails db:verify_no_schema_drift`                            | PASS: 20 schema dumps; same isolated parent fleet, one worker setting                                                                              |
| `bin/rails identifiers:inventory`                                | PASS for read-only catalog scan; same fleet, `REPORT=tmp/nine-independent-inventory.json`                                                          |

Dependency advisory refresh/audits, full CI orchestration, deployment, browser E2E, fresh-parent
migration/rebuild/dump/restore, historical HMAC-role rollback and real operational cutover were
NOT_RUN. They are not implied by the successful commands above. Asset preparation used the existing
Rails test harness; no separate production build is certified.

## Confirmed counterexample: permanent public identity

**ID-4 FAIL**, specifically `AppPreference`, `ComPreference`, `OrgPreference`. Inside a
rollback-only transaction on each verified disposable database, create a synthetic record through
`model.create!`, retain its generated public ID, generate a second value using `PublicId.generate`,
call `record.update_columns(public_id: replacement)`, and reload. All three models persisted the
replacement inside the transaction; the original value changed. The outer transaction then raised
`ActiveRecord::Rollback`. No existing row was modified and no synthetic row was retained. Sequence
allocation is not rolled back by PostgreSQL.

Reproduction body, run by `bin/rails runner` under the isolated test environment above with one
worker:

```ruby
Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!
[AppPreference, ComPreference, OrgPreference].each do |model|
  model.transaction(requires_new: true) do
    record = model.create!
    original = record.public_id
    replacement = PublicId.generate
    record.update_columns(public_id: replacement)
    raise "probe did not reproduce" unless record.reload.public_id == replacement && original != replacement
    puts "#{model.name}: forbidden identity update accepted"
    raise ActiveRecord::Rollback
  end
end
```

`app/models/concerns/public_id.rb` validates immutability only through ordinary validated updates.
The existing capacity tests prove rejection of values over 25; they do not reject a different valid
21-character identity. The reference document already distinguishes model validation from database
immutability and holds new all-table mechanisms pending scoped authority. That hold explains the
unfinished implementation; it does not make ID-4 pass. This observation alone is sufficient to
reject global completion, without claiming every public-ID table is affected.

## Email span observation and flush defect

The actual development initializer was booted with `OPEN_TELEMETRY=true` and
`OTEL_TRACES_EXPORTER=none OTEL_METRICS_EXPORTER=none OTEL_LOGS_EXPORTER=none`. An
`OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter` and synchronous `SimpleSpanProcessor`
captured synthetic `process.action_mailer` and `deliver.action_mailer` notifications for
`Email::App::OtpMailer`, `Email::Com::OtpMailer`, and `Email::Org::OtpMailer`. Payloads contained
synthetic subject/address/message ID/body/mail/OTP/token/args and unknown future secret fields. Six
spans were captured: process attributes were exactly `action, mailer`; deliver attributes were
exactly `email.x_mailer`. The synthetic marker was absent from captured span attributes/events and
the in-memory Rails logger. `ActionMailer::Base.logger` was nil. No SMTP delivery or live collector
export was used. This proves the notification-to-span primary allowlist subcondition, not all actual
mail delivery, queued failure/retry or downstream sinks.

The first capture attempted `OpenTelemetry.tracer_provider.force_flush` and failed with
`ArgumentError: comparison of TrueClass with 0 failed`. The configured scrubber processor in
`config/initializers/opentelemetry.rb:82` returns `true`; installed `opentelemetry-sdk` 1.13.1
aggregates processor results with `results.max`, and the synchronous exporter returns numeric
success. The second capture omitted the unnecessary flush for the synchronous processor and passed.
No application code was changed. The first error remains a genuine SDK integration defect; the
successful capture does not repair it or establish reliable batched-export flushing. `shutdown` has
the same boolean source shape but was not independently diagnosed in this investigation.

## Database and runtime observations

The catalog inventory covered 20 writer connections and 892 tables. Missing/composite primary keys,
Hash indexes, invalid indexes and unready indexes were all zero. The 40 non-bigint primary keys were
exactly the 20 `schema_migrations` and 20 `ar_internal_metadata` framework tables. The 238
`public_id` columns had these physical types: 183 varchar(21), 52 unbounded varchar, one
varchar(255), one varchar(25), one varchar(16). Named capacity CHECKs and role classification must
be considered separately; these physical widths alone neither prove compliance nor prove a violation
for protocol/human/legacy exceptions. The two retained legacy-table holds remain explicit in
`docs/reference/identifier-conventions.md`; their migration was not performed here.

The concrete Avatar tests use independent backend connections and real COMMIT, including ownerless
creation rejection, accepted adjacency, rejected gap/overlap and races at READ COMMITTED, REPEATABLE
READ and SERIALIZABLE. The focused run executed these cases successfully. D-11 is therefore
partially demonstrated, not wholly blocked for lack of any isolation infrastructure. It still
requires the broader transfer/failure/recovery campaign; successful period races alone cannot close
it. Four transfer directions, expiry boundaries and historical Grant non-reactivation exist in and
were exercised through the focused transfer test file.

The app/org public registry admission explicitly requires `AvatarOwnershipCutover.established?`.
`AvatarOwnershipPeriodSource` preserves legacy authority before the marker and concrete authority
after it. This demonstrates a staged implementation, not a completed operational transition. The
current Avatar checklist already settles Group account context as distinct from organization
ownership; the remaining cutover is not permission to invent a new Group meaning.

`command -v alloy podman docker` found no available executable. Collector syntax/processor runtime
and Compose rendering were therefore NOT_RUN in this environment. The YAML declares one nested Alloy
bind with `read_only: true` and shared `selinux: z`. However,
`findmnt -T /home/global/workspace/podman/alloy -n -o TARGET,FSTYPE,VFS-OPTIONS` returned
`/home/global/workspace zfs rw,noatime`: the current session has no separate read-only Alloy mount.
This fails the runtime mount subcondition for this session; host recreation and a write-denial probe
were not performed. No claim is made about another host or production.

## Criterion dispositions

Rows describe the whole parent criterion unless a narrower scope is explicit. PARTIAL means
implemented/observed subconditions with identified remaining acceptance work, not a failing test.
Full-suite success executes the existing tests; it does not certify missing scenario partitions. The
added ID-3a–q / ID-4a–f slices remain bounded subcontracts of these parent criteria; their presence
does not supersede the ID-4 counterexample or certify the all-table inventory.

| Criterion | Disposition                          | Observation and remaining boundary                                                                                                      |
| --------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| ID-1      | PARTIAL                              | Catalog PK shape passes; complete synthetic writer/migration preservation campaign not run                                              |
| ID-2      | PARTIAL                              | Generation/capacity tests pass; all normal/bulk/import producer partitions not independently exhausted                                  |
| ID-3      | PARTIAL                              | Scoped reference inventory exists; all issuer/kind/consumer and retained legacy classifications remain incomplete                       |
| ID-4      | FAIL                                 | Three concrete Preference `update_columns` counterexamples above                                                                        |
| ID-5      | PARTIAL                              | Existing collision tests run in full suite; exhaustive named-constraint/bulk writer classification not established                      |
| ID-6      | PARTIAL                              | No Hash/invalid/unready indexes; full collation/partition/ordering consumer audit not performed                                         |
| ID-7      | PARTIAL                              | Existing protocol compatibility tests run; full provider/issued-reference migration map not certified                                   |
| ID-8      | PARTIAL                              | Executable invariant coverage exists; ID-4 gap demonstrates incomplete negative coverage                                                |
| CONTACT-1 | PARTIAL                              | Independent Email/Telephone policy code and six-model tests exist; full sentinel/lifecycle boundary mapping not independently exhausted |
| CONTACT-2 | PARTIAL                              | Realm rotation/maintenance tests run in suite; historical HMAC-role recovery is not rehearsed here                                      |
| CONTACT-3 | PARTIAL                              | Realm encryption/rotation tests run; full current/previous-key operational boot matrix not rerun separately                             |
| CONTACT-4 | PARTIAL                              | Concurrent ceremony verification passes; every purpose/provider/realm applicability cell remains unclosed                               |
| CONTACT-5 | PARTIAL                              | Retirement/delivery/fault regressions run; complete consumer/transport retirement sign-off remains incomplete                           |
| CONTACT-6 | PARTIAL                              | All-six-model concurrent normalized creation passes; complete create/delete/reuse race matrix not certified                             |
| CONTACT-7 | PARTIAL                              | Purge/rollback/owner-substitution regressions pass; all raw/bulk/whole-owner and cross-DB erasure paths not independently exhausted     |
| CONTACT-8 | PARTIAL                              | Keyed HMAC then Argon2id construction inspected, repeated history tested; full maintenance/consumer misuse audit not completed          |
| CONTACT-9 | PARTIAL                              | Visibility/retention regressions run; final privacy/retention decisions remain separately owned                                         |
| FLOW-1    | PARTIAL                              | Root session-establishment tests pass; complete route/family/provider applicability matrix remains incomplete                           |
| FLOW-2    | PARTIAL                              | APP sign-up safe refusal/reload/deadline cases pass; all GET/HEAD endpoint matrix not certified                                         |
| FLOW-3    | PARTIAL                              | APP unsafe HALT and absorption cases pass; complete locked revalidation/terminal consumer matrix remains unclosed                       |
| FLOW-4    | PARTIAL                              | APP stale A/new B and malformed binding tests pass; full cross-family callback matrix not certified                                     |
| FLOW-5    | PARTIAL                              | Stale-tab/committed-account and existing concurrency tests run; exhaustive finalization/issuance race campaign not completed            |
| FLOW-6    | PARTIAL                              | APP durable halt audit regression passes; every family audit and diagram edge not independently reconciled                              |
| AV-1      | PARTIAL                              | Concrete ownership/provisioning tests pass; all retained-data writers/cutover not certified                                             |
| AV-2      | PARTIAL                              | Real COMMIT adjacency/gap/overlap/history protections pass; full transition/recovery campaign outstanding                               |
| AV-3      | PARTIAL                              | Three isolation-level concrete-period races pass; complete transfer lock/failure campaign outstanding                                   |
| AV-4      | PARTIAL                              | Shared registry and four-direction operation tests pass; all consumer activation/cutover conditions remain                              |
| AV-5      | PARTIAL                              | Idempotency/replay tests run; complete HTTP actor/authority/client-transition matrix outstanding                                        |
| AV-6      | PARTIAL                              | Four-direction transitions/expiry/Grant consequences pass; full failure injection and cutover acceptance outstanding                    |
| AV-7      | PARTIAL                              | Historical Grant non-reactivation test passes; exhaustive supported subject/capability/generation matrix not certified                  |
| AV-8      | PARTIAL                              | Separate account meaning preserved and transfer consequence tested; full data/consumer cutover outstanding                              |
| AV-9      | PARTIAL                              | Retention-deferral tests run; final personal-attribute retention/deletion policy unresolved                                             |
| MAIL-1    | PASS, tested filtering boundary      | Existing positive/negative filter tests pass; no all-sink assurance implied                                                             |
| MAIL-2    | PARTIAL                              | Test and development logger nil; existing delivery tests run; independent all-surface DEBUG/failure/retry capture not exhausted         |
| MAIL-3    | PARTIAL                              | Actual synthetic notification spans obey allowlists; SDK flush defect and full actual-delivery capture remain                           |
| MAIL-4    | BLOCKED, local runtime               | Alloy/container executable absent; static config is not processor execution                                                             |
| MAIL-5    | PARTIAL; runtime subcondition FAIL   | Correct bind declaration; current effective mount is workspace rw, no host recreation/write-denial probe                                |
| MAIL-6    | PARTIAL                              | Local verification stayed within scope; historical diff/production/owner-review closure not certified                                   |
| PROC-1    | PASS for this investigation          | Current clean snapshot identified; existing work preserved                                                                              |
| PROC-2    | PARTIAL                              | Authority holds recorded; prior approval-before-edit chronology not audited exhaustively                                                |
| PROC-3    | PARTIAL; Gate 4 FAIL                 | Current regression gates executed, coverage gate fails; historical Red/Green and cadence not reconstructed                              |
| PROC-4    | NOT_RUN, historical chronology       | No feature edits here; past hold adherence cannot be inferred from current code                                                         |
| PROC-5    | PARTIAL                              | Current independent result recorded; unresolved acceptance and stale/planned coverage remain                                            |
| PROC-6    | NOT_RUN, historical commit authority | No commits made; historical restricted-commit compliance not audited                                                                    |
| MIG-1     | PARTIAL                              | Current catalog and schema drift pass; full fresh migration/sequence/restore campaign not run                                           |
| MIG-2     | PARTIAL                              | Completed migration objects present in tested fleet; six-draft provenance and complete fresh restore/recovery not re-audited            |
| MIG-3     | PARTIAL                              | Verified workers and real-COMMIT/isolation tests pass; full rebuild/role/transfer failure campaign outstanding                          |
| MIG-4     | PARTIAL                              | Barrier/source/operation tests run; writer-quiescence, complete rehearsal and forward recovery not executed here                        |

## Required next work

1. Resolve the scoped mechanism/authorization for permanent public-ID database protection, then
   implement it and add negative coverage that catches the three reproduced bypasses.
2. Repair the OTel span processor SDK return contract and verify real flush behavior with a local
   exporter. Preserve the passing allowlist boundary.
3. Meet the existing JavaScript coverage gate without lowering thresholds or excluding uncovered
   product behavior merely to make acceptance green.
4. Close the remaining route/purpose/realm, physical-purge and transfer failure matrices. Preserve
   current real-COMMIT successes and extend only missing cells; do not describe the whole harness as
   unavailable.
5. Perform the separately controlled isolated migration/cutover/recovery rehearsals and host Alloy
   runtime/mount verification, and obtain the unresolved privacy/retention decisions. Production
   activation is outside this investigation.

No corrective application implementation is included in this acceptance task.

## Final postflight

After the full Rails process exited with status 0, the safety verifier again validated all 20 parent
databases against their manifest identities. A read-only `pg_database` query for the exact 80
expected worker names (20 parents times four worker suffixes) returned zero remaining databases. No
manual cleanup was needed. This closes the current run's worker-cleanup subcondition, not the
separate historical HMAC-role/rebuild campaign.

The final knowledge checker passed with the same scope counts. HEAD was unchanged, both tracked and
staged diffs were empty, and `git status --short` showed only this untracked evidence file. The
regenerated OpenAPI bundles matched the existing tracked versions. Generated logs, inventory,
coverage and transient probe scripts remain local ignored or `/tmp` artifacts, not evidence
payloads.
