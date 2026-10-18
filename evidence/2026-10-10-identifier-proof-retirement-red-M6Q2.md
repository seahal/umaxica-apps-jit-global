# Identifier proof retirement Red

Executed on 2026-10-10 against HEAD `2a1644f73238839ed7ed513bd4681ea393a86682` with uncommitted
code, migrations, tests and documentation. This is an unfinished P3d TDD iteration, not Green, slice
completion or acceptance.

The public record contract in `test/models/otp_failure_retention_test.rb` now requires each of the
six concrete identifiers to expose neither old lifecycle methods nor stored attributes
`otp_private_key`, `otp_counter`, `otp_expires_at`. The existing blank-value assertions were
replaced with absent-attribute assertions, strengthening the accepted retirement requirement.

Command: `bundle exec rails test test/models/otp_failure_retention_test.rb -i /stored_proof_fields/`
with test/Rack environment, workers 1, owned manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, run `20261010p8b`, host `primary`, and its full
preparation database list.

Observed: 6 runs, 36 assertions, 6 failures, zero errors/skips. Each concrete model fails because it
still stores `otp_private_key`; this is the expected contract failure, not environment failure. No
migration or production change was applied in this Red step. Continue this same iteration with
forward migration/model/consumer retirement; do not begin another feature or claim Green. The
previously completed full gate predates this deliberately failing test.

## Forward migration preparation

Rails generated three migrations, reviewed and populated with explicit typed `remove_column`
operations for the three legacy fields on the six source tables:

- `db/app_principals_migrate/20261010230339_retire_client_identifier_hotp_fields.rb`
- `db/com_principals_migrate/20261010230343_retire_visitor_identifier_hotp_fields.rb`
- `db/org_principals_migrate/20261010230350_retire_operator_identifier_hotp_fields.rb`

The fields are not referenced by the serialized-context triggers; those protect distinct context
columns and remain for the later context-retirement step. Each reverse operation recreates the
verified original type/default/nullability but cannot recover discarded proof values. No existing
migration was edited. These new migrations have NOT been applied. Complete source encryption,
initialization and obsolete test-attribute retirement before invoking automatic preparation. The
unfinished iteration remains Red; no next feature slice is authorized by this preparation.

## Initial Green on the owned fleet

The first `db:test:prepare` stopped before applying retirement because strong_migrations required
ignored-column declarations. Added those to the six models, removed their old key encryption and
structural key/counter initialization, and documented the deploy-before-drop requirement beside the
narrowly scoped safety_assured blocks. The approved disposable rehearsal uses one code snapshot;
this does not authorize a real-data deployment or waive retained-data recovery approval.

Retried `bundle exec rails db:test:prepare` under the same owned manifest: exit 0; all three
retirement migrations applied. `bundle exec rails test test/models/otp_failure_retention_test.rb`
then passed: 32 runs, 426 assertions, zero failures/errors/skips. This proves the initial public
model contract, not completed P3d: obsolete test creation attributes and wider public consumer
tests, context retirement, schema dumps/rebuild verification, and both full gates still remain. No
other feature slice may begin before this schema slice and its gates are reconciled.

## Consumer cleanup and running full gate

Obsolete source creation attributes were removed from existing test fixtures without changing
ceremony proof fields. Source-field assertions now require absence instead of blank structural
values where updated. The neighboring command containing `otp_failure_retention_test`, Email and
Telephone credential-registration issuer tests, withdrawal anonymizer, encryption re-encryption and
HMAC emergency rotation passed: 59 runs, 770 assertions, zero failures/errors/skips.

`git diff --check` passed after the remaining inline fixture cleanup. `bun run test` passed: 99
files, 1,140 tests, exit 0, 13.18 seconds. The required full `bundle exec rails test` was started
under the same owned manifest, workers 1, with complete preparation scope; its result is still
pending. This is not a completed Gate 2. Schema dump/rebuild and serialized-context retirement also
remain incomplete. No next feature slice has begun, and no application/test/migration commit or push
was made.

## Physical catalog check

A read-only `bundle exec rails runner` first called
`Umaxica::TestEnvironment::DatabaseSafety.verify!` under the owned manifest, then queried
`information_schema.columns` on each concrete model connection for its public source table and the
exact three retired names. Exit 0: ClientEmail, ClientTelephone, VisitorEmail, VisitorTelephone,
OperatorEmail and OperatorTelephone each returned an empty remaining-column list. This establishes
physical absence on this disposable fleet rather than relying on `ignored_columns`; it does not
verify fresh rebuild or any production database.

## Full gate result

The same full `bundle exec rails test` completed with exit 0: 15,013 runs, 127,304 assertions, zero
failures/errors/skips, 969.139769 seconds. Combined with the current Vitest result above, this
passes the schema slice's regression gate. The previous successful baseline had 15,013 runs and
127,308 assertions; this run had four fewer assertions. Assertion totals alone do not establish
contract coverage; current public contract and neighboring tests are described above. both actual
result sets have no failures, not merely matching failure counts. The full run used HEAD above plus
the uncommitted current implementation/test/migration changes and owned test fleet. This does not
establish completed P3d, fresh rebuild, serialized-context retirement or independent acceptance.

## Schema dump verification

`bundle exec rails db:schema:dump:app_zenith db:schema:dump:com_zenith db:schema:dump:org_zenith`
completed with exit 0 under the owned manifest. Existing Avatar dump differences were preserved. The
generated source dumps remove the retired columns and add the three migration versions;
database-specific HMAC definer names reflect the owned fleet, not newly created shared roles.

`bundle exec rails db:verify_no_schema_drift` exited 1, listing the uncommitted app_zenith,
com_zenith, org_zenith and Avatar structure files. It is NOT PASS. A separate read-only Rails runner
loaded the existing Rake verifier, checked database safety, and called
`SchemaDriftVerification.dump_matches?` with temporary files for app_zenith, com_zenith and
org_zenith: all returned true, exit 0. This confirms current DB-to-worktree dump correspondence
without claiming committed-schema cleanliness. Application/schema commit authority was not expanded
to erase this reported drift. Fresh rebuild and serialized-context retirement remain open.
