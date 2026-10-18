# Org entry Cancel navigation

Commit: `91974b8b05ccda80afcb1beb3174ab48f4155889`.
Checks used the existing dirty worktree, including prior chooser changes and this follow-up.
Unrelated changes were preserved.

Org sign-in removes the top back link and its unused prop; Cancel remains plain text at the end.
Org sign-up replaces the top back link with a trailing native Cancel anchor, using exactly the
previous `auth_org_root_path` destination and the existing `actions.cancel` translation. Its
suspended page still renders only its notice. No cancellation action or state mutation was added.

- The updated org sign-up frontend assertion failed before implementation for missing Cancel.
- `bun run test -- spec/pages/auth/org/org_auth_screens.test.tsx`: 25 tests passed, including absent
  top navigation, trailing Cancel link destination, text-only sign-in Cancel, and suspension behavior.
- `bin/rails test test/controllers/auth/org/sign_ins_controller_test.rb test/controllers/auth/org/sign_ups_controller_test.rb`
  outside the sandbox: 20 tests, 106 assertions, zero failures/errors/skips.
- RuboCop on both org entry controllers and their tests, Oxfmt on both entry components and their
  spec, and `git diff --check`: passed.
- Full suites, type checking, and live browser rendering were not repeated for this org-only change.
