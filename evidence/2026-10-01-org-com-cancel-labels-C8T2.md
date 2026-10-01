# Org/com chooser Cancel labels

Commit: `91974b8b05ccda80afcb1beb3174ab48f4155889`.
Verification used the existing dirty worktree, including the earlier app placeholder changes and
this uncommitted follow-up. Unrelated changes were preserved.

Org and com sign-in/sign-up entry pages now receive `cancel_label: t("actions.cancel")` and render
it last as a plain paragraph. No cancellation route, link, button, form, or behavior was added.
Com sign-in retains its original methods and has no app/provider separator; the shared separator
requires social providers as well as the Cancel label. Suspended sign-up pages retain notice-only
rendering.

- New frontend assertions first failed for missing Cancel or the unwanted com separator.
- `bin/rails test test/controllers/auth/com/sign_ins_controller_test.rb test/controllers/auth/com/sign_ups_controller_test.rb test/controllers/auth/org/sign_ins_controller_test.rb test/controllers/auth/org/sign_ups_controller_test.rb`
  outside the sandbox: 32 tests, 172 assertions, zero failures/errors/skips.
- `bun run test`: 87 files and 1,067 tests passed, including text-only and final-position assertions
  for all four org/com choosers and the app chooser regression tests.
- RuboCop on the four controllers and four corresponding test files: no offenses after whitespace
  correction. Oxfmt on the seven changed TSX files and `git diff --check`: passed.
- Full Rails suite and type checking were not repeated for this display-only follow-up. The earlier
  evidence records the full Rails result and two unrelated type-check errors. Live browser
  verification was not performed.
