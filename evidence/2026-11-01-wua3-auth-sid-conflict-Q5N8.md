# WU-A3 attached Auth SID conflict boundary

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the
  worktree had 367 tracked modified paths and 72 untracked paths, with no staged paths. Existing
  work was preserved; no commit was created.
- The Auth sign-in entry now compares the current host-only `auth_sid` with the exact active Auth
  continuity row before redirecting or redeeming an attached or Base-confirmed binding. A mismatch
  uses the shared 409 refusal boundary. The direct App and Org `/ceremony_bindings` endpoint maps
  the same session-binding mismatch to that refusal. Other malformed/consumed references retain
  their existing 400 response.
- The AC-53 initial-attach race test covers App and Org, both cookie arrival orders, immediate 409
  from the losing entry, direct binding endpoint refusal, no Auth/session cookie or DBSC response,
  unchanged losing binding/parent/session, normal progress for the last-cookie target, and retention
  cleanup. The foreign-browser admission boundary test now checks the same 409/no-mutation contract.
  The A12-4 consumed-relay test still expects and received 400.
- Focused command:
  `bin/rails test --seed 60888 test/integration/acceptance_wua3_initial_attach_race_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb test/controllers/auth/app/sign_ins_controller_test.rb test/controllers/auth/org/sign_ins_controller_test.rb test/controllers/auth/app/sign_ups_controller_test.rb test/controllers/auth/org/sign_ups_controller_test.rb`
  — 80 runs, 1,289 assertions, 0 failures, 0 errors, 0 skips. Tests used local test databases only.
- Targeted RuboCop passed for the three controllers/concerns and two tests (5 files). `ruby -c`
  passed for all 5 Ruby files. Scoped `git diff --check` passed.
- An earlier combined run showed the existing foreign-browser test expected 400 where §10.6 requires
  409; that expectation was updated and the no-mutation assertions were added. An initial broader
  mapping also changed the consumed A12-4 replay to 409; the implementation was narrowed to
  attached/base-confirmed status IDs, and the focused A12-4 replay test passed with 400.
- No migration or schema dump was changed in this slice. No full suite was run. This does not close
  WU-A3 or the remaining `two.md` work.
