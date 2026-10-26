# WU-24h Admission ownership and child-first collection

Revision: `ba570a0007b1d40eabe32990a34831317fd98a93`.
Observed on 2026-10-23/24 with uncommitted implementation, tests, documentation and generated OP
schema dumps affecting the results. No deployment or production data operation was performed.

## Scope and changes

WU-24h implements D-125/D-127 and the D-159/D-168 empty-database migration workflow. The checkpoint
already contained APP/COM required ownership, immutable assignment, explicit creation bindings,
admitted-owner lookup and the four generated FK/index migrations. This iteration added the missing
child-first collector, production owner-write guard, separate-connection insert races and HTTP
ownership coverage, and generated the corresponding schema dumps.

`AuthAdmissionBindingPurger` locks all child Flows in ID order. One in-progress, retained or
cleanup-incomplete child retains the entire set and its Binding. Collection deletes eligible Flow
rows before their restrictive Binding, leaves the parent and Auth sessions for their own owners,
and never deletes principals. Completed registration bypasses artifact cleanup, but preserves its
physical-retention boundary, including infinite retention. Creation refuses expired/canceled
parents; the locator also refuses a Flow class from another surface.

## Executed verification

- Before the collector repair, the added purge tests produced four real PostgreSQL RESTRICT
  errors: APP/COM active and cleanup-incomplete children blocked the old direct Binding delete.
- Final related regression command:

  ```sh
  rg -l -0 'SignUpAdmissionTestFactory' test --glob '*_test.rb' | xargs -0 bin/rails test test/models/sign_up_flow_admission_ownership_test.rb test/models/sign_up_flow_admission_concurrency_test.rb test/controllers/auth/sign_up_admission_ownership_test.rb test/operations/auth_admission_binding_purger_test.rb test/security/invariants/sign_up_admission_owner_write_invariant_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb
  ```

  Result: **592 runs, 5662 assertions, 0 failures, 0 errors, 0 skips**. This is a related subset,
  not a full-suite result or reconciliation of the original cycle-wide failures.
- APP/COM two-worker insert races observed two distinct PostgreSQL backend PIDs and exactly one
  successful Flow insert and one uniqueness refusal for each Binding.
- HTTP tests use encrypted Rails UI cookies and real admitted Auth SIDs. Foreign hints, foreign
  signed Flow URLs and wrong nonces are refused over GET/POST/PATCH/DELETE, with CSRF protection
  enabled, no redirect, no-store, no Root creation and unchanged Binding/Ceremony/parent/Flow rows
  for both attempts. Six HTTP tests alone passed with 216 assertions.
- Missing/nonexistent FK, immutable ownership, terminal history, creation expiry at one microsecond
  below/at/above the cutoff, canceled parents, malformed hints, restrictive deletion, cleanup holds,
  physical-retention cutoff and registered-principal preservation are covered through public APIs.
- Ten changed/new Ruby files passed RuboCop; scoped `git diff --check` passed. No test-helper or
  global test setup change was made in this iteration.

Three existing regressions needed contract/fixture correction: missing admission now returns 400
rather than a Flow-dependent 404; the Step Gate receives its explicit controller-owned Flow and
classifies a supplied expired Flow as unusable; the expiry job test freezes both owning database
clocks so admission fixture construction cannot cross its one-second live boundary. Assertions
were retained and updated to those contracts; no test was removed or skipped.

## Migration and schema observations

- Ordinary scoped development migrations completed. Immediately before rollback, read-only counts
  observed zero `client_sign_up_flows` and zero `visitor_sign_up_flows` in both development and test.
- Executed `RAILS_ENV=development bin/rails db:rollback:op_base_app db:rollback:op_base_com STEP=2`
  and the equivalent test command. All four generated migrations reverted in each environment.
- Executed `db:migrate:op_base_app db:migrate:op_base_com` in both environments; all four migrations
  reapplied. This proves empty-table reversibility only, not recovery of populated ownership data.
- Executed scoped development `db:schema:dump:op_base_app db:schema:dump:op_base_com` after
  reapplication. Each dump adds 18 lines corresponding to the new required column, partial unique
  index and restrictive FK. No dump was edited by hand.
- Using the actual `SchemaDriftVerification.dump_matches?` implementation against temporary dumps,
  all three OP writer configurations matched in both development and test after reapplication
  (six successful comparisons). The runner selected exactly those three writers and rejected any
  missing configuration or mismatch.
- The required unmodified global `db:verify_no_schema_drift` command **failed** in development:
  HMAC definer role does not match `development_com_zenith_db`.
- The equivalent global test command **failed** on `app_zenith`, `com_zenith`, `org_zenith` and
  the two uncommitted OP dumps. The verifier includes uncommitted dump differences in its gate;
  the live OP comparisons do not waive this or the Zenith discrepancies. The verifier was not
  weakened and the Zenith state was not rebuilt in this iteration.

## Remaining scope

A24-3, A24-4 and A24-10 now have the scoped verification above. The complete 44-unit goal stays
open. Remaining WU-24 work includes its full acceptance reconciliation, the WU-24e actual
Passkey-save/termination HTTP race, global schema verification and explicit new-FK agreement for
legacy Base social-completion readers. Those readers still select by signed result `actor_ref`;
their existing signed candidate/session checks are not evidence of the new FK agreement.

Curfew enforcement, unfinished-registration refusal, social unification, Visa separation, standard
refresh, authority-stop v2 and the other ledger items remain separate required work. These results
do not certify those behaviors or an end-to-end six-path registration journey.
