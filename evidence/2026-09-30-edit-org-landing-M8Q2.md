# Edit org landing

Commit: `f8c93e4a9a50e22a942976a5810962f039662206`.
The worktree contained unrelated uncommitted changes and the landing/Cookie-link changes.

The landing now uses Edit's layout with Base's existing visual conventions and links to the
existing Publishing authentication boundary, Base registration entry, and Base preferences.
Signed-in operators see a Publishing link instead of registration. No authentication protocol,
authorization policy, route, or persistence schema was changed.

- Before implementation, the two new landing tests failed on absent navigation/layout elements.
- Final `bin/rails test test/controllers/edit/org/roots_controller_test.rb
  test/controllers/edit/org/dashboards_controller_test.rb
  test/integration/cookie_settings_authority_test.rb test/integration/sign/app/layout_test.rb`
  passed: 8 tests, 60 assertions, no failures or errors.
- `bundle exec erb_lint app/views/edit/org/roots/index.html.erb
  app/views/layouts/edit/org/application.html.erb` passed.
- RuboCop passed for the Edit root controller and both new test files. Checking SurfaceChrome
  also reported an existing unrelated `Style/TernaryParentheses` offense at line 126, in work
  already present before this task; that line was preserved.
- `bin/vite build` succeeded outside the sandbox, with a chunk-size warning. The initial
  sandboxed build could not initialize Rails' debugger socket but completed asset generation.
- `git diff --check` passed.

The deployed Edit and Base URLs were inaccessible through the web tool. No browser tooling was
available, so responsive appearance and the complete OIDC round trip remain unverified in a
browser. No deployment was performed.
