# Base Authority inheritance boundary

- Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`.
- Worktree had inherited and current uncommitted changes.
- Owned `20261007fresh3` test fleet; seed 42, serialized Rails execution.

The seven-file admission/CSRF/result/concurrency/static-boundary matrix initially reported
125 runs, 1,961 assertions, one failure and no errors/skips. Its old static guard incorrectly
included Base self-RP application controllers among Authority controllers. Inspecting actual
Authority superclasses then exposed a real production boundary defect in all three realms:
the unqualified `ApplicationController` parent resolved to the same-namespace Base self-RP class.
Runtime inspection reported `RP=true, root=true` for each Authority controller.

The corrected static guard directly tests Auth and Base Authority for absence of OIDC initiation,
RP authentication and safe/unsafe RP refresh concerns. A separate positive self-RP guard checks
RP authentication remains and root authentication does not. The focused file failed before the
production fix (3 runs, 50 assertions, one failure).

All three Authority parents now explicitly name `::ApplicationController`; their independently
declared root-session lifecycle and standard CSRF remain intact. No social callback, route,
admission policy or security control was weakened to pass the tests.

```bash
bin/rails test test/controllers/auth/admission_csrf_transport_test.rb \
  test/controllers/auth/ceremony_admission_boundary_test.rb \
  test/controllers/auth/step_up_admission_test.rb \
  test/services/auth_admission_binding_concurrency_test.rb \
  test/services/base_auth_admission_coordinator_test.rb \
  test/services/identity/ceremony_result_numeric_date_test.rb \
  test/security/invariants/auth_base_authority_boundary_test.rb --seed 42
```

Result after the fix: **126 runs, 2,016 assertions, zero failures, errors or skips**.
Runtime reinspection confirmed each Authority superclass is global `ApplicationController`, with
`RP=false, root=true`. The additional eight-file Step-Up issuer/bootstrap/conflict/cancellation,
restart-race, admission and app/com email-sign-in matrix passed at seed 1744 after this split:
**181 runs, 2,439 assertions, zero failures, errors or skips**. Scoped RuboCop corrected four
formatting offenses in the static test and then exited 0.
Documentation records the namespace-resolution invariant in the existing boundary ADR and
controller lifecycle guide. The full suite and Final Verification remain open.
