# WU-A3 Admission Binding status predicates and redemption test contract

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 506 modified or untracked paths and no staged changes. Existing changes were preserved; no
commit was created.

`AuthAdmissionBinding#attached?` and `#confirmed?` now derive their current lifecycle predicates
from the approved `status_id` values. Their decision no longer depends on the presence of the
attachment references or nullable confirmation timestamp. The model test covers issued, attached,
Base-confirmed, redeemed, retired, and switched values in both App and Org models.

The redemption boundary test was aligned with the current public contract: a missing or foreign
`auth_sid` against an attached binding returns 409, and the explicit OIDC lifecycle is read through
`status_name`. It continues to assert no parent, binding, Auth session, or continuity mutation for
refused requests.

Verification with `.env.container.devcontainer` loaded and `PARALLEL_WORKERS=1`:

- `bin/rails test test/models/auth_admission_binding_test.rb test/services/auth_admission_binding_concurrency_test.rb test/controllers/auth/admission_redemption_input_boundary_test.rb test/controllers/auth/ceremony_admission_boundary_test.rb`:
  108 runs, 1,516 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/integration/acceptance_wua3_initial_attach_race_test.rb`: 1 run, 164
  assertions, 0 failures, 0 errors, 0 skips. The App/Org arrival-order cases returned 409 for a
  target that does not match the current cookie and retained the no-mutation assertions.
- Targeted RuboCop inspected the three changed Ruby files with no offenses. `ruby -c` passed for all
  three; scoped `git diff --check` passed.

An initial two-file run exposed stale expectations: 56 failures from comparing the old OIDC `status`
string rather than `status_name`, and expecting 400 for cookie-to-binding mismatch. After those
expectations were updated, a second run had only the two missing-cookie cases still expecting 400;
the final targeted run passed after those were aligned to 409. This evidence records current focused
results only; no full suite was run, and WU-A3 and the broader `two.md` work remain open.
