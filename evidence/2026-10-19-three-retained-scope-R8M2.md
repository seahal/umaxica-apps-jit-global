# Retained three.md scope: implementation follow-up

Date: 2026-10-19. HEAD: `ff58ff28125fafe405dc76809f6498b64d69e627`. The worktree contains
substantial unrelated, staged, unstaged and untracked work. Checks include uncommitted cycle
changes; no unrelated changes were restored or removed.

## Scope reconciliation

Current six.md and three.md record the user deferral of withdrawal assurance, Avatar
preparation/restoration, final deletion/retention and capacity control. They also record the later
Cancel/Switch ordering decision. Earlier zero.md prose still described these as unanswered cycle
blockers. The prose was corrected without implementing deferred behavior or touching the user-owned
Inertia dependency changes.

## Confirmed defects and corrections

- Extra Passkey audit metadata could replace `surface`, `external_id` and `actor_ref` during
  delivery. The outbox writer now rejects those reserved keys before insertion. Registration and
  audit persistence remain in the owning transaction.
- APP Activity Log omitted historical ClientChronicle Passkey registration/removal from its
  visible-event catalog. Both events now map to their existing translated labels. The legacy query
  uses a final ID tie-breaker before applying its limit, consistent with the presentation merge.
- Registration could accept an existing credential or a record whose actual class disagreed with the
  explicit class. It now requires a new record of the selected surface's Passkey class.
- Registration controllers/committers still translated every UNIQUE violation into a Credential ID
  conflict. They now recognize only the three PostgreSQL `webauthn_id` unique index names; other
  uniqueness failures propagate. The old error message that included the database exception text was
  removed. Real database tests distinguish Credential ID and external UUID collisions.

## Completed checks before the final Activity Log correction

The 19-file affected Ruby boundary group passed after the audit correction:
`217 runs, 1484 assertions, 0 failures, 0 errors, 0 skips`. It covers both Cancel/Switch integration
files; Passkey operation and delivery; withdrawal timing, lifecycle, ceremony and security; APP
Activity presenter; OIDC resolver and authority; sanitizer; retention purge; signup cleanup;
credential removal; Passkey ceremony commit; anonymizer; and the Passkey writer invariant. This is
focused evidence, not full acceptance of every scenario in four.md.

New public-interface audit tests cover all-surface rollback on invalid metadata, all-surface outer
transaction rollback, delayed nil-actor system delivery after physical credential deletion, and
retry with a Chronicle event already committed but not yet acknowledged. The registration/delivery
subset passed: `12 runs, 70 assertions, 0 failures, 0 errors, 0 skips`.

`bun run test` passed: 100 files and 1157 tests. `bun run typecheck` exited zero.

Ruby test commands explicitly used the current `.env` database manifest with
`env -u POSTGRESQL_TEST_PREPARE_DATABASES`, an explicit `POSTGRESQL_TEST_PREPARE_DATABASES` value,
and `PARALLEL_WORKERS=1`. No concurrent Ruby test command was run against the same database fleet.

## Schema verification limitation

`RAILS_ENV=development bin/rails db:verify_no_schema_drift` exited 1 before comparing dumps:
`ArgumentError: HMAC definer role does not match database development_com_zenith_db`, from
`SchemaDriftVerification.normalize_roles`. No database-role or schema change was inferred from this
failure. Production operation and external provider/storage execution remain unverified.

## Final affected-boundary verification

All final production corrections were included in an isolated, two-worker run using the existing
receipt-verified fleet (`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261017c1a2`, manifest
`tmp/acceptance-isolated-20261017c1a2.json`). `POSTGRESQL_TEST_PREPARE_DATABASES` was explicitly
derived from that manifest's database names and `PARALLEL_WORKERS=2` was set.

Command: `bin/rails test` with these paths:

```text
test/integration/sign_entry_exit_flow_test.rb
test/integration/sign_entry_exit_com_org_flow_test.rb
test/operations/passkey_registration_operation_test.rb
test/jobs/passkey_audit_delivery_job_test.rb
test/values/umaxica/withdrawal/timing_policy_value_test.rb
test/services/withdrawal_lifecycle_test.rb
test/integration/withdrawal_lifecycle_security_test.rb
test/integration/withdrawal_ceremony_session_test.rb
test/integration/withdrawal_ceremony_reentry_test.rb
test/presenters/base_identity_activity_log_presenter_test.rb
test/resolvers/oidc_authorize_request_resolver_test.rb
test/controllers/base/oauth_oidc_authority_test.rb
test/policies/chronicle_record_policy_test.rb
test/jobs/retention_purge_job_test.rb
test/services/sign_up_artifact_cleanup_test.rb
test/operations/identity_credential_removal_committer_test.rb
test/operations/identity_passkey_ceremony_final_committer_test.rb
test/operations/withdrawal_personal_data_anonymizer_test.rb
test/security/invariants/passkey_registration_writer_invariant_test.rb
test/integration/base_passkey_mutation_step_up_test.rb
test/models/client_passkey_test.rb
test/models/visitor_passkey_test.rb
test/models/operator_passkey_test.rb
test/models/webauthn_duplicate_registration_test.rb
```

Result: **267 runs, 1688 assertions, 0 failures, 0 errors, 0 skips**. The first attempt had two
test-data setup errors: legacy audit rows used an infinite discard time with a finite purge
deadline. Correcting the setup to satisfy the existing retention invariant resolved both; the final
run above includes those tests.

The five existing committed Avatar test files were also run on this isolated fleet:
`avatar_retention_purge_test.rb`, `avatar_concrete_ownership_period_test.rb`,
`avatar_transfer_reservation_test.rb`, `avatar_moniker_writer_operation_test.rb`, and
`avatar_ownership_transfers_concurrency_test.rb`. Result: **43 runs, 189 assertions, 0 failures, 0
errors, 0 skips**. This separate fleet run did not share the ordinary full-suite databases.

`bundle exec rubocop --force-exclusion` on the ten Ruby files changed in this follow-up passed with
no offenses. Scoped `git diff --check` passed.

An actual worker boot check with
`RAILS_ENV=development UMAXICA_APP_COM_WITHDRAWAL_RECOVERY_DELAY_SECONDS=0 bin/jobs check` exited 1
during timing-policy initialization with the expected positive-integer error. This proves invalid
development timing is refused before the worker starts; it does not certify production startup or
deployed workers.

## Whole-suite result and remaining acceptance

`bin/rails test` with the ordinary `.env` manifest and `PARALLEL_WORKERS=1` completed: **15572 runs,
132690 assertions, 2 failures, 18 errors, 0 skips** (exit 1). This run started before the final
presenter and constraint-classification corrections; the 267-test isolated run above is the evidence
for the final affected code.

- Fourteen errors explicitly require run-owned worker receipts in committed Avatar tests. All five
  affected files passed on the receipt-verified isolated fleet (43/189 above).
- The remaining two failures and four errors concern `inertia_rails/devtools/entries` route
  ownership/authentication-mode inventory and missing `clearHistory` fields in Inertia page/cache
  contracts. Their files are `runtime_role_route_ownership_test.rb`,
  `authentication_mode_inventory_test.rb`, `inertia_page_contract_test.rb` and
  `authenticated_response_cache_policy_test.rb`. This matches the user-owned Inertia upgrade
  limitation already recorded in zero.md. Gemfile, Gemfile.lock and the Inertia dependency contract
  were not changed in this follow-up; no tests were skipped or relaxed to hide these failures.

The code corrections and affected automated checks are complete for this follow-up. The whole
repository is not green. Schema verification is blocked as described above. Manual real-browser
acceptance, production startup/worker operation, and provider/storage execution were not performed.
These limits prevent a blanket READY/complete-acceptance claim and are not reopened design questions
for the user-deferred work.
