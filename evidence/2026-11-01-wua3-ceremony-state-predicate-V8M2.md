# WU-A3 Auth Ceremony status predicate alignment

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. At the start of this slice the worktree had 503
modified or untracked paths and no staged paths. This evidence file and the two focused code/test
changes were added without disturbing the existing changes.

`AuthCeremonySession#admitted?` now reads the approved explicit `status_id` set. `admitted_at`
remains a stored event fact and is not used to decide the current lifecycle status. The model test
for predecessor replacement checks that the terminal `replaced` status is not admitted while the
original admission timestamp remains unchanged.

Verification with `.env.container.devcontainer` and `PARALLEL_WORKERS=1`:

- `bin/rails test test/models/auth_ceremony_session_test.rb test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`
  passed: 30 runs, 214 assertions, 0 failures, 0 errors, 0 skips.
- A wider nine-file admission, binding, ceremony concurrency, purger, and Secret claim selection ran
  89 tests and 1,445 assertions. It had 4 failures and 0 errors/skips, all in
  `Auth::App::SignInAdmissionTest`; the four test IDs are already listed as failures in
  `plans/2026-10-28-baseline-failing-tests.md`. The remaining tests in that selection passed. This
  run does not establish a cause for those baseline failures.
- Follow-up on `Auth::App::SignInAdmissionTest` with the required document-navigation headers ran 7
  tests and 13 assertions, with the same 4 cases failing. The positive cases reached the current
  clean-URL `303` response where their assertions expect an inline `200` continuation form; replay
  cases then posted without that form and received `404`. The test file was restored after this
  probe. Its assertions remain an unresolved baseline discrepancy.
- `ruby -c` passed for both changed Ruby files; RuboCop inspected both with no offenses;
  `git diff --check` passed.

This slice verifies the Auth Ceremony predicate change only. The WU-A3 acceptance matrix and the
broader `two.md` work remain open.

## Follow-up: App Sign In admission request contract

After the header-only probe, the App Sign In admission test was updated to use the repository's
`admit_auth_ceremony_entry!` helper, which performs the current binding attach, Base confirmation,
and confirmed-entry GET redemption. The test now checks the replaced attached ceremony, new admitted
ceremony, clean redirect, ignored unsigned `pt`, idempotent same-browser replay, and refusal when
the Auth cookie is absent. This follows `two.md` §12.1; no application route behavior changed.

- The revised test file passed: 7 runs, 45 assertions, 0 failures, 0 errors, 0 skips.
- Re-ran the same nine-file admission/binding/concurrency/purger/Secret-claim selection: 89 runs,
  1,477 assertions, 0 failures, 0 errors, 0 skips.
- Syntax checks passed for the three changed Ruby files; RuboCop inspected all three with no
  offenses; `git diff --check` passed.
- At this follow-up the worktree had 505 modified or untracked paths and no staged paths. HEAD was
  still `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.

The earlier baseline entries for the old inline-form expectations no longer represent the revised
current test contract. No full suite was run.
