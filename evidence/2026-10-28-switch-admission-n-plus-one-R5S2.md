# Switch Admission N+1 on Repeated Sign In / Sign Up Switches

Date: 2026-10-28. Commit: `b6e7871073bdc43a55fc5f05e8476de8ee71252f`. The worktree also held
uncommitted changes that do not affect this result: the owner's `.devcontainer/compose.yaml` edit and
the Base ORG translation-key move recorded in `evidence/2026-10-27-base-org-translation-namespace-K4T7.md`.

## Finding

The owner reported `Prosopite::NPlusOneQueriesError` in development after switching between Sign In
and Sign Up two or three times. `BaseAuthAdmissionCoordinator.create_or_reuse_binding!` checked that
every redeemed Binding of the parent belonged to a cancelled ceremony by calling
`admitted_ceremony_session(binding)` once per Binding (one `find_by` each). Each Switch leaves one more
redeemed Binding on the parent, so the query count grew with the number of Switches.

## Change

- The check now loads the ceremonies of all redeemed Bindings in one query
  (`redeemed_ceremonies_all_cancelled?`). A missing ceremony row still counts as not cancelled, so the
  refusal is unchanged. The now-unused `admitted_ceremony_session` was removed.
- The design issue behind it (no explicit end state on the Binding, unbounded Switches per parent) is
  recorded as `one.md` R-AU-42 and is not changed here.

## Verification

- New test "app Switch reads the earlier ceremonies in one query however many Switches the parent has
  had" in `test/services/admission_binding_deadline_intent_test.rb`: Red before the change
  (expected 1, actual 3 ceremony SELECTs on the third Switch), Green after.
- New test "app Switch is refused while an earlier redeemed Binding's ceremony is still live": Green.
- `bin/rails test test/integration/sign_entry_exit_flow_test.rb test/integration/sign_entry_exit_com_org_flow_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb test/services/auth_admission_binding_concurrency_test.rb test/services/admission_binding_deadline_intent_test.rb`:
  78 runs, 1409 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop on the two changed files: no offenses.

- After the change, the owner repeated the Sign In / Sign Up Switch in a browser on the development
  server and reported that the error no longer occurs (owner-reported, 2026-10-28).

Not done: the full test suite.
