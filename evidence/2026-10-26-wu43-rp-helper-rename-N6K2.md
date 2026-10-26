# WU-43 RP sign-in helper rename

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`

The worktree was already dirty. At the verification snapshot, `git status --short` reported 886
entries, including staged, unstaged, and untracked changes. Those changes were preserved; nothing
was staged or committed.

## Inventory

| Lane | Definition or caller | Classification |
|---|---|---|
| RP | `app/controllers/concerns/browser_rp_authentication.rb` | Builds the unauthenticated redirect through the RP target helper. |
| RP | `app/controllers/concerns/oidc_sso_initiator.rb` | Calls and defines the shared RP helper. |
| RP | `app/controllers/base/{app,com,org}/application_controller.rb` | Base surface implementations of the RP helper. |
| RP | `app/controllers/base/{app,com,org}/authority_controller.rb` | Base neutral sign-entry implementations of the RP helper. |
| RP | `test/controllers/concerns/oidc/callback_test.rb` | RP callback test controller implementation. |
| Auth | `app/controllers/concerns/authentication_base.rb` | Auth abstract method contract and two internal calls. |
| Auth | `app/controllers/concerns/authentication_{client,visitor,operator}.rb` | Auth method implementations. |
| Auth | `app/controllers/auth/{app,com,org}/application_controller.rb` | Auth surface implementations. |
| Auth | `app/controllers/auth/{app,com,org}/roots_controller.rb` | Auth root callers. |
| Auth | `test/controllers/concerns/auth/{base,redirect_bulletin,cookie_helpers}_test.rb`, `test/controllers/concerns/authentication/base_extra_coverage_test.rb`, `test/integration/auth_booster_test.rb` | Auth test doubles and signed-`pt` behavior coverage. |
| Text only | `test/security/invariants/forbidden_patterns_invariant_test.rb` | Two existing allowlist regexes contain the former spelling; they do not define or call it. The new invariant scans RP production paths and the RP callback fixture for that spelling. |

The RP helper is now named `sign_in_url_with_target` in its callers and definitions. RP output still
uses the existing path-only `target_link_uri` handling. `AuthenticationBase`, Auth controllers,
Auth roots, signed `pt` processing, routes, and redirect behavior were not changed.

## Verification

- RP/OIDC suite and invariant file: 132 runs, 877 assertions, 0 failures, 0 errors, 0 skips.
- Auth `pt` suite: 82 runs, 198 assertions, 0 failures, 0 errors, 0 skips.
- Re-run of the static invariant file: 5 runs, 38 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails zeitwerk:check`: passed. Rails warned that the vendored `rails_db` directory is outside eager-load paths; the application check completed successfully.
- RuboCop on the nine implementation and RP test files: no offenses. The changed invariant file passed `Layout/MultilineAssignmentLayout`; the full ten-file RuboCop command reported three pre-existing `Layout/LineLength` offenses at lines 233, 241, and 249 of that file.
- `git diff --check` on the changed code files: passed.
