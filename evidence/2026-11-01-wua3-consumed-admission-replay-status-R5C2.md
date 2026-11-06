# WU-A3 consumed admission replay response status

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file was added, the worktree
had 503 unstaged tracked paths and 234 untracked paths; no staged changes. The existing worktree was
preserved and no commit was created. The affected test file already contained other uncommitted
WU-A3 changes.

`two.md` §5.3 and §10.6 require a no-mutation 409 for a stale or mismatched ceremony phase. Two
public Auth replay assertions still expected 400 after the current implementation returned 409:
replaying a redeemed entry from a second browser, and restoring the predecessor `auth_sid` before
replaying the redeemed entry. Updated those expected statuses to 409. The foreign Visa confirmation
receipt assertion remains 400; an intermediate attempt to change it to 409 failed against the
observed response and was reverted because it is an invalid receipt rather than an Auth phase
refusal.

The focused command below passed: 43 runs, 1,133 assertions, 0 failures, 0 errors, 0 skips.

```sh
set -a; source .env.container.devcontainer; set +a
PARALLEL_WORKERS=1 bin/rails test \
  test/services/auth_admission_binding_concurrency_test.rb \
  test/controllers/auth/ceremony_admission_boundary_test.rb \
  test/integration/acceptance_wua3_initial_attach_race_test.rb
```

`ruby -c test/controllers/auth/ceremony_admission_boundary_test.rb`, scoped RuboCop for that file,
and `git diff --check` passed. No application code, schema, or database data changed in this slice.
No full suite was run. This verifies only the selected WU-A3 admission and replay cases; broader
WU-A3 and `two.md` acceptance remain open.
