# P1: non-transactional test residue and fixture-load foreign keys

## Result

`bin/rails test` from a pristine test database, 16 workers:

```text
16703 runs, 140230 assertions, 333 failures, 223 errors, 0 skips
foreign-key violation messages: 0
```

Before this work the same suite reported 5,506 foreign-key errors out of 414 failures and 5,688
errors; an intermediate run after the first four fixes still reported 1,288 foreign-key errors (all
`enterprise_units`), which is how the remaining source was found. The 333 failures and 223 errors
that remain are the other categories (sign-up 503, HTML parsing, preference shape, mail sign-in 400,
OpenAPI 403, independent-commit conflicts, misc) — none of them is a foreign-key failure, and their
count moves between runs because another agent's work was landing in this worktree throughout.

Run markers: `test databases are in use: 0`, `db:test:prepare failed: 0`,
`Migrations are pending: 0`.

## What was measured

All files that set `self.use_transactional_tests = false` — 107 files (a plain grep for the phrase
matches 111 because four files only mention the flag in a comment).

For every file: restore all 26 writable test databases from a pristine template, run the file with
`PARALLEL_WORKERS=1`, then diff every `public` table's exact row count against (a) the pristine
template and (b) a fixture-only baseline produced by a transactional `fixtures :all` run. A
fixture-reload probe (a second `fixtures :all` run, which re-enables every foreign key) follows,
because that re-enabling step is where leftover rows raise.

```text
python3 .../snapshot.py .../fixture_baseline.json     # fixture-only baseline
python3 .../measure.py  .../leaks.ndjson              # all 111 matched files vs pristine
python3 .../verify2.py                                 # suite-ordered check of each fixed file
bash .../bisect.sh <start> <end>                       # primed slices of the non-transactional set
bin/rails test                                        # full suite
```

## Sources of residue that broke fixture loads

| file                                                                                                                                                                                                                       | residue                                                                                                                                                                                                               | why the cleanup missed it                                                                                                                                                                                                                      |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test/integration/app_secret_signup_journey_test.rb`                                                                                                                                                                       | 21 complete bootstrap graphs (`client_identities`, `personas`, `persona_assignments`, `persona_memberships`, `enterprise_units`, `enterprise_unit_closures`, `enterprises`) plus 21 `client_registration_completions` | `uses_transaction` makes all 24 sign-up cases commit; sign-up completion runs `IdentityGraphProvisioner`, and the teardown deleted the actor but never the graph                                                                               |
| `test/integration/sign/app/credential_removal_constraints_test.rb`                                                                                                                                                         | 8 × `enterprise_units`, `persona_memberships`, `enterprise_unit_closures` (+ 8 personas, identities, assignments)                                                                                                     | bootstrap links a non-eligible principal to its collective through the _membership_ graph, not through `EnterpriseOwnership`; the teardown only deleted clients                                                                                |
| `test/integration/sign/org/credential_removal_constraints_test.rb`                                                                                                                                                         | 5 × `bureaus`, `bureau_units`                                                                                                                                                                                         | same pattern through `BureauOwnership`, and the id relations were lazy so they re-ran their subquery after the rows they needed were deleted                                                                                                   |
| `test/integration/telephone_signup_http_delivery_test.rb`                                                                                                                                                                  | 4 × `client_telephones` + ceremony transactions, 16 sessions, 8 bindings, 4 OIDC transactions, 4 flows, 4 clients                                                                                                     | `ClientTelephone.find_by(number:)` compares plaintext against a non-deterministically encrypted column and never matches, so `cleanup_signup_records` returned early; the entry admission binding also pinned the sessions and the transaction |
| `test/operations/avatar_ownership_transfers_concurrency_test.rb`, `test/jobs/avatar_retention_purge_test.rb`, `test/models/avatar_transfer_reservation_test.rb`, `test/operations/avatar_moniker_writer_operation_test.rb` | 1 bare `enterprise` (or `bureaus`) per run                                                                                                                                                                            | teardown removed membership/unit/persona rows but never the collective row itself                                                                                                                                                              |

Mechanism of the original 5,506 failures: fixture loading deletes and re-inserts `enterprises`,
`clients`, … inside `disable_referential_integrity`, then re-enables every foreign key in the
schema. A leftover row in a table without a fixture file (`enterprise_units`, `persona_memberships`)
still points at a row the reload just deleted, so re-enabling raises and the _next_ test fails in
`before_setup`. `client_telephones` and `client_emails` are truncated only by classes that declare
them, so a class that declares `clients` but not them fails the same way.

## Fixes (test files only; no production code changed)

1. `test/integration/app_secret_signup_journey_test.rb` — teardown derives identities → personas →
   membership → enterprises/units from the actor with materialized ids and deletes the graph
   (including `ClientOidcIdentityBinding` and `AvatarPersonaBinding`) before the client. A second
   addition deletes `ClientRegistrationCompletion` rows: another agent's in-flight
   `ClientRegistrationCompletion` work started committing those receipts during this session and
   they blocked the client delete.
2. `test/integration/sign/app/credential_removal_constraints_test.rb` — same membership-derived
   graph cleanup.
3. `test/integration/sign/org/credential_removal_constraints_test.rb` — the collective is derived
   from `AgentMembership` (plus `BureauOwnership` when present) and every id relation is
   materialized with `pluck` instead of being left lazy.
4. `test/integration/telephone_signup_http_delivery_test.rb` — lookup through the digest-based
   `with_number` scope, and the cleanup also removes the entry admission binding that shares the
   flow's OIDC authorization transaction.
5. The four avatar tests — the created `Enterprise`/`Bureau` is recorded on an instance variable and
   deleted in teardown.

`bin/rubocop` reports no offenses on the eight edited files.

## Residue that remains, and why it is not removed

- Reference rows the application creates on demand (`persona_membership_kinds/states`,
  `agent_membership_kinds/states`, preference option tables, the new
  `client_registration_completion_methods` seeds): no foreign key points out of them.
- `client_oidc_connections`, `operator_oidc_connections`, `client_sign_in_flows`: no outgoing
  foreign key to a fixture-loaded table; their token rows reference them, not the other way round.
- Avatar history (`avatars`, `handles`, `avatar_monikers`, `avatar_*_ownership_periods`): the
  immutability and truncate triggers reject `DELETE`, and no fixture-loaded table references them.
- Audit outbox rows (`client_passkey_audit_outboxes`, …): keyed by public-id strings.
- Seed-versus-fixture count differences (`client_statuses` 13 vs 12, `jwt_occurrences` 198 vs 120,
  `avatar_ownership_statuses` 4 vs 0): tables whose fixture file is empty or absent.

## Harness caveat found while measuring

Running a non-transactional file against a _pristine_ database (no fixture load yet) produces
foreign-key failures the suite never produces: a class with a restricted fixture set reloads
`clients` while `client_telephones`/`client_emails`/`operator_token_binding_methods` still hold
seeded or created rows, and Avatar rows created before the first `fixtures :all` load reference
seeded `avatar_lifecycle_states` ids that the first load replaces. Priming the databases with one
transactional `fixtures :all` run before each slice removed all of those, and the whole
non-transactional set then measured clean (slice and probe both 0).

## Test database reset

All 26 writable test databases were dropped and recreated (`RAILS_ENV=test bin/rails db:drop`,
`RAILS_ENV=test bin/rails db:create`,
`POSTGRESQL_TEST_PREPARE_DATABASES=… RAILS_ENV=test bin/rails db:test:prepare`) because the previous
run had left committed rows in them (393 avatars, 28 personas, 7 clients, 9 enterprises, 28
identities …). `db:test:prepare` also applied three migrations another agent added to the worktree
while this work ran (`20261102064741_create_client_registration_completions` and its two
follow-ups), and the worker and replica clones were rebuilt from the reset bases before the suite
started.

## Verification commands

```text
bin/rails test test/integration/app_secret_signup_journey_test.rb
bin/rails test test/integration/sign/app/credential_removal_constraints_test.rb
bin/rails test test/integration/sign/org/credential_removal_constraints_test.rb
bin/rails test test/integration/telephone_signup_http_delivery_test.rb
bin/rails test test/jobs/avatar_retention_purge_test.rb test/models/avatar_transfer_reservation_test.rb
bin/rails test test/operations/avatar_moniker_writer_operation_test.rb test/operations/avatar_ownership_transfers_concurrency_test.rb
bin/rails test
```

Per-file results after the fixes (suite-like order: fixtures primed, file, fixture-reload probe):
`8 runs … 0 failures, 0 errors` / `5 runs …` / `4 runs …` / `3 runs …` / `14 runs …` / `6 runs …` /
`6 runs …` / `24 runs …`, every probe `ok`.

## Revision and worktree

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`
- The worktree carried broad uncommitted changes before this work (the preference-shape cutover,
  sign-in changes and related tests), and another agent kept committing to it during this session:
  three new `client_registration_completions` migrations,
  `app/models/client_registration_completion.rb`, `sign_up_sequence_controller_support.rb` and
  several registration operations changed, and their test batches ran against the same test
  databases. The full-suite totals above therefore include their in-flight state; the foreign-key
  count does not depend on it (0 in the final run, and the non-transactional set measured 0 on its
  own).
- No paths were staged.
