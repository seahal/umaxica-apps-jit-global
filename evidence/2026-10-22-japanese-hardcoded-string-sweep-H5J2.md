# Japanese hardcoded string sweep

- Date: 2026-10-22.
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: uncommitted implementation, translations, tests and documentation affected these checks.
- Scope: `plans/backlog/restoration-h5-japanese-hardcoded-string-sweep.md`.

## Observations

- Initial `rg -n '[ぁ-んァ-ヶ一-龠]' app --glob '*.rb' --glob '*.erb'` found five lines,
  all in `app/views/pwa/offline.html.erb`. Repeating after extraction returned no matches.
- Baseline PWA endpoints and locale integrity tests: 11 runs, 209 assertions, no failures,
  errors or skips.
- `bin/rails test test/controllers/pwa_endpoints_test.rb test/initializers/locale_bundle_integrity_test.rb test/initializers/locale_test.rb`:
  25 runs, 656 assertions, no failures, errors or skips. Added coverage renders both languages
  across all ten origins and checks title, heading, description, retry label, accessible label,
  HTML language and absence of Set-Cookie.
- Independently parsed all four bundles with Ruby YAML and verified all four `pwa.offline` keys
  contain nonempty strings in each bundle.
- `bundle exec rubocop test/controllers/pwa_endpoints_test.rb`: no offenses after correcting
  initial test formatting findings and marking the expected English sentence as translation data.
- `bundle exec erb_lint app/views/pwa/offline.html.erb`: no errors; emitted a parser Ruby version
  compatibility warning.
- `git diff --check`: passed.

## Limits

No browser or offline service worker installation test was run. The framework controller does not
resolve user locale preferences. The existing worker caches the document rendered during installation;
changing user locale does not refresh that cache. This work adds translations without changing that
lifecycle. The full Rails suite was not run.
