# Edit RP logout return verification

Date: 2026-10-25

Full git commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`

Worktree: it was already dirty at task start (`git status --porcelain` listed 783 paths). The test changes in this record were uncommitted and affected the results. No files were staged.

## Contract checked

- `Edit::Org::Sign::OutsController` includes `SignOutClearSiteData`; its state-bound completion returns `Clear-Site-Data` with storage clearing. No production change was needed.
- `Base::Org::SignOutsController` completes through `BaseSignOutDestination`; the state-bound completion renders an Inertia page with `clearHistory` enabled.
- The new test pins the OP and callback hosts from `Rails.configuration.x.boot_config.fetch(:hosts)`. The matrix now expects each OP host from the configured Visa APP, COM or ORG host by RP actor class, independently of `OidcIssuer`.
- Edit missing-state and wrong-state callbacks return 404 without consuming the completion; the issued state completes once and a replay returns 404. APP and COM OPs reject the Edit hint in JSON with 400. Their HTML requests render a generic 200 page without redirecting to Edit; the RP grant and operator root remain unchanged for both response formats.

## Verification

| Command | Result |
|---|---|
| `bin/rails test test/integration/oidc_rp_logout_edit_return_test.rb` | 1 run, 64 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/integration/oidc_rp_logout_registered_rp_matrix_test.rb` | 1 run, 241 assertions, 0 failures, 0 errors, 0 skips |
| `bundle exec rubocop test/integration/oidc_rp_logout_edit_return_test.rb test/integration/oidc_rp_logout_registered_rp_matrix_test.rb` | 2 files inspected, no offenses |
| `git diff --check -- test/integration/oidc_rp_logout_registered_rp_matrix_test.rb` and trailing-whitespace scan of the new test | Passed |

This task changed only the two test files and this evidence record; existing dirty application, route and configuration changes were preserved. The generic HTML response for a rejected cross-realm hint is an existing response-format behavior; the test verifies it does not redirect to the Edit return URI or mutate either authority record. This task did not change that presentation behavior.
