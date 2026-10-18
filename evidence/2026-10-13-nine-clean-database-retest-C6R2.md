# Nine acceptance retest after a clean database rebuild

Date: 2026-10-13. Full HEAD: `4828aeedd141b54163236672890799b9b01128c2`. The worktree includes the
prior OTel correction, three setting-Preference migrations and schema dumps, acceptance tests and
documentation. Other contributors' ADR/research changes were also present and were preserved. This
retest introduces no implementation or test changes; this evidence record is its only intended
repository edit. No commit or production action was performed.

## Reset scope and reconstruction

The user requested a database reset, migration and test-based judgment. Reset scope was the existing
owned disposable fleet `20261013n9a`, described by `tmp/acceptance-isolated-20261013n9a.json`. The
p8b parent fleet and shared/development/production databases were not reset. Earlier synthetic
rehearsal rows in n9a were intentionally discarded.

The existing `scripts/postgresql-rebuild-isolated-test-fleet --verify-only` passed for 20 databases
and 12 scoped HMAC roles. Its checks include database identity/OID/owner/comment, no active target
sessions, the run lock, role creation receipts and absence of foreign/shared role dependencies. The
same command without `--verify-only` completed with exit 0: dropped only those databases, removed
their 12 orphaned roles, recreated the 20 databases and refreshed ownership receipts.

Reconstruction executed `db:test:prepare` using the repository's `migrate(skip_initialize: true)`
path, followed by `db:migrate`; both succeeded. This executes source migrations on the empty fleet
rather than importing migration receipts from structure dumps. The fresh creation log contains one
successful migration each for ProtectAppPreferencePublicId, ProtectComPreferencePublicId and
ProtectOrgPreferencePublicId. The final manifest has 20 databases and 12 roles, and the creation-log
SHA-256 matches its recorded value.

All 20 fresh database schemas matched the current worktree schema files via fresh temporary dumps
and the existing public `SchemaDriftVerification.dump_matches?` comparison. This is not a claim that
the intended schema changes are committed; the prior Git-diff-sensitive schema gate result in P3V8
remains historical and was not relabeled as passing.

## Commands and environment

Commands ran from `/home/global/workspace` with `RAILS_ENV=test`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261013n9a`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261013n9a.json`,
`POSTGRESQL_TEST_HOST=primary` and `POSTGRESQL_DATABASE=postgres`.
`POSTGRESQL_TEST_PREPARE_DATABASES` was populated with all 20 names from that manifest. Normal
configured PostgreSQL credentials were used without exposing them.

- `PARALLEL_WORKERS=1 bundle exec scripts/postgresql-rebuild-isolated-test-fleet --verify-only`
- `PARALLEL_WORKERS=1 bundle exec scripts/postgresql-rebuild-isolated-test-fleet`
- `PARALLEL_WORKERS=4 bin/rails test`
- `bun run test`
- `PARALLEL_WORKERS=1 bin/rails runner /tmp/nine-id-dump-match.rb`

The rebuild wrapper first loaded `config/application` to resolve configured database variables, then
executed the existing command. No custom reset logic or protection bypass was introduced. Fresh
temporary schema matching used the previously inspected direct runner, not a new setup unit test.
Logs and manifests remain local ignored/transient artifacts; no raw logs or dumps are included in
this evidence file.

JavaScript completed successfully: 99 test files, 1,140 tests, exit 0 (13.47 seconds).

## Final result: tests do not pass after reset

The full Minitest run on the rebuilt fleet completed with **15,250 runs, 128,964 assertions, one
failure, one error, zero skips**, in 322.31 seconds; seed 58812, process exit 1.

- Known failure: `Auth::Org::Sign::In::PasskeysControllerTest`'s durable halt regression at
  `test/controllers/auth/org/in/passkeys_controller_test.rb:237` still observes zero durable halt
  audit records instead of one. Resetting the database did not repair it.
- Additional error: `PasskeyMutationAuthorizationTest`'s APP/COM verified-email management case at
  `test/operations/passkey_mutation_authorization_test.rb:172` fails while creating its COM token at
  line 190. PostgreSQL rejects `visitor_token_binding_method_id = 0` because
  `visitor_token_binding_methods` has no matching row; constraint
  `fk_customer_tokens_on_customer_token_binding_method_id`.

The exact second case was rerun alone with one worker on n9a: **one test, four assertions, zero
failures, one error, zero skips**, same missing-reference error, exit 1. This was not an external
provider or reset-command failure. The class explicitly sets `fixture_table_names = []` and creates
a token without arranging this required reference data.

Read-only queries on both verified parent fleets returned:

| Fleet                                    | `VisitorTokenBindingMethod.order(:id).pluck(:id)` |
| ---------------------------------------- | ------------------------------------------------- |
| Fresh n9a                                | `[]`                                              |
| Preserved p8b used by the preceding runs | `[0, 1, 2]`                                       |

The standalone failure demonstrates missing test prerequisites on a clean database. The previous
full-suite pass for that case is not evidence that it is independent of retained reference data or
test order. This diagnosis does not establish which production/bootstrap owner should initialize the
catalogue; no fixture, global helper, seed, application callback or migration was changed to mask
the error. The user requested reset and judgment, not a new initialization-policy change.

## Postflight and snapshot limits

After both test processes exited, the read-only postflight verified all 20 n9a parent identities and
zero remaining worker databases. No manual worker cleanup was needed. Content hashes of 7,254
implementation/test/configuration/migration/script/dependency files were identical before reset and
after retesting; HEAD was unchanged. Concurrent documentation work is not represented as a globally
frozen worktree. `git diff --check` and the evidence-selected repository knowledge check passed. The
three-setting-table ID correction produced no failure in this full run, but neither that success nor
a successful reset supplies a global acceptance GO.
