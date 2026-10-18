# CF-011 idempotency and receipt-boundary recheck

- Date: 2026-09-23
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: pre-existing and current uncommitted changes were preserved; no reset, cleanup,
  commit, push, GitHub write, provider access, or shared-data operation was performed.

## Adversarial finding and correction

The first local CF-011 implementation generated a different idempotency digest for every attempt.
That would allow a retry after an ambiguous processor response to be interpreted as a second external
request. This contradicted the request-idempotency requirement.

The contract now stores one digest-only idempotency identity per notification delivery generation.
All retry attempts in that generation reuse it. Authorized manual recovery increments the generation
and creates a new identity. Attempt rows retain the identity for receipt lookup, while attempt number
remains unique and monotonic within the generation. The attempt idempotency index is therefore a
non-unique lookup index, not a uniqueness constraint that would prevent retries.

The receipt lookup selects the latest attempt for the matching notification, generation, and
generation-scoped idempotency identity. A receipt from a different notification, processor,
generation, or digest is rejected. The receipt consumer rejects any adapter result that is not a
`ProcessorErasureVerifiedReceipt`; an unverified acknowledgement cannot transition the notification
to `NOTIFIED`.

The receipt application path also rechecks terminal notification state under the row lock. A late
valid receipt cannot reopen a `PERMANENT_FAILURE`, `SKIPPED`, or other terminal notification.

The due-work scope now obtains its default comparison time from the owning writer database clock;
callers may still pass the already-captured decision time when they need one shared comparison for a
batch. A public scope regression covers both sides of the due boundary.

Migration rollback was adversarially reviewed as well. The delivery-contract rollback now restores
notification foreign-key status values before removing the permanent-failure reference row. The
idempotency correction refuses to restore the old unique digest index when valid retry history has
created duplicate generation-scoped keys; it raises `ActiveRecord::IrreversibleMigration` before
changing the schema instead of performing a destructive merge or leaving a partial rollback.

## Verification performed

Static checks passed after the correction:

```text
ruby -c <changed state, migration, and delivery-contract test files>  # Syntax OK
bundle exec rubocop <changed CF-011 files>                             # 25 files, no offenses
git diff --check                                                       # passed
bundle exec brakeman -q                                                # 0 errors, 0 warnings
```

A DB-free value-contract smoke check passed with:

```text
bundle exec ruby -Iapp -r active_support/all \
  -r ./app/values/processor_erasure_retry_policy \
  -r ./app/values/processor_erasure_verified_receipt \
  -r ./app/values/processor_erasure_dispatch_result \
  -e '<finite retry and verified-receipt construction checks>'
```

Result: `processor-value-contract-ok`, including rejection of a non-hex/non-64-character receipt
idempotency digest.

After the terminal-state receipt guard was added, the complete 25-file CF-011 syntax/RuboCop set
was rerun with no offenses, `git diff --check` still passed, and a second `bundle exec brakeman -q`
reported 0 errors and 0 security warnings.

## Runtime verification status

The required environment was selected without displaying values:

```text
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db
```

The required environment variables were present after loading. `config/credentials/test.key` was
present and its contents were not read. The required preflight failed before application checks:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records. The focused delivery
contract test, migration execution, PostgreSQL constraint checks, independent-connection concurrency
checks, queue execution, and full Rails suite were therefore not run in this session. No localhost
fallback, mock runtime, `/etc/hosts` edit, Compose edit, or test weakening was used.

CF-011 remains `OPEN — EVIDENCE REQUIRED` for the pre-deployment scope until the focused PostgreSQL-
backed contract tests and migration/locking evidence run in the attached Compose environment.
Provider authentication, provider receipt protocol, and provider E2E remain separate deployment /
provider gates.

The same required preflight was rerun after the terminal-state, database-clock, and migration
rollback corrections and failed with the same unresolved `primary` hostname. Focused and full Rails
tests were not started because the preflight prerequisite remained unmet.

## Current-process recheck

The required environment file was selected again on 2026-09-23. After `LocalEnvironment.load!`, all
required PostgreSQL/Valkey variable names were present and `config/credentials/test.key` was present
without reading its contents. The exact preflight still failed with:

```text
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

Both `getent hosts primary` and `getent hosts valkey-kvs` returned no records. No fallback host,
hosts-file edit, Compose edit, mock, skipped test, or weakened assertion was used.

The current-process static recheck passed:

```text
ruby -c <CF-011 Ruby, migration, and test files>                     # all Syntax OK
bundle exec rubocop <22 CF-011 implementation, migration, and test files> # no offenses
bundle exec brakeman -q                                                # 0 errors, 0 warnings
git diff --check                                                        # passed
```

The DB-free value-contract smoke check returned `processor-value-contract-ok`, including rejection
of an invalid receipt idempotency digest. Rails Minitest, migration execution, PostgreSQL
constraint/concurrency checks, and queue runtime evidence remain unexecuted because the preflight
cannot resolve the required service aliases.

## Compose-backed acceptance recheck

The same test procedure was subsequently run with the process attached to the local Podman Compose
network. The repository and worktree were not reset, and no external service, provider, GitHub
remote, production database, or shared database was accessed. `config/credentials/test.key` was
confirmed present without reading its contents. The explicit test environment was selected without
printing values. The preflight succeeded against the local services:

```text
PostgreSQL test target: 10.89.0.3/32:5432, PostgreSQL 17.7
Valkey rate_limit: valkey-kvs:6379, db=4, PONG, Valkey 7.2.4
Valkey auth_state: valkey-kvs:6379, db=6, PONG, Valkey 7.2.4
```

The test databases for app_zenith and com_zenith were rebuilt only through Rails' standard
test-database tasks. Migration execution initially exposed and then corrected three schema issues:
strong_migrations-required `NOT VALID` checks, concurrent index replacement, and a PostgreSQL
63-character constraint-name truncation. From clean isolated test databases, both delivery-contract
migrations and their validation migrations completed successfully. The generated SQL structure
dumps were then loaded through the standard Rails reset tasks.

Focused acceptance results after the corrections:

```text
bin/rails test <CF-011 focused set>                         # 30 runs, 118 assertions, 0 failures, 0 errors, 0 skips
bin/rails test <schema/architecture/object-placement set>  # 17 runs, 3118 assertions, 0 failures, 0 errors, 0 skips
bin/rails test <combined set after structure load>          # 47 runs, 3236 assertions, 0 failures, 0 errors, 0 skips
```

The full Rails suite was run after focused tests and after the implementation corrections:

```text
bin/rails test                                              # 11560 runs, 73578 assertions, 0 failures, 0 errors, 8 skips
```

The eight skips are existing repository skips reported by the suite; no skip was added for this
change. Repository-wide RuboCop completed with no offenses, `git diff --check` passed, and
`bundle exec brakeman -q` reported 0 errors and 0 security warnings. The earlier non-escalated
DNS failure remains historical environment evidence; it is superseded for this run by the
successful local Compose-backed preflight above.

The pre-deployment CF-011 acceptance evidence is now complete: notification and attempt schema
constraints, receipt binding, retry exhaustion, immutable permanent failure, manual recovery,
parent deletion behavior, due-only bounded retry selection, and independent-connection concurrency
behavior were exercised through public interfaces. Provider authentication, provider-specific
receipt protocol, real credentials, and provider E2E remain separate deployment/provider gates.

**CF-011 status: CLOSED — PRE-DEPLOYMENT ACCEPTANCE SATISFIED.**

Final read-only PostgreSQL metadata verification after the structure-load reset reported, for both
app and com: `delivery_idempotency_key_digest` is `NOT NULL`; all idempotency-related CHECK
constraints are validated; the attempt-to-notification foreign key has `ON DELETE CASCADE`; and
the generation-scoped idempotency lookup index is non-unique. No secret, token, or credential value
was printed.
