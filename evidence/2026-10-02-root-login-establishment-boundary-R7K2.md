# Root Login Establishment Boundary Verification

- Commit: `3b3163e655e91d967ba86174a7f24ee9dbb9c4cd` (branch `feature`), with uncommitted changes: the pre-existing working-tree changes
  listed at session start plus this change (see `adr/root-login-establishment-boundary.md`).
- Environment: Ruby 4.0.7, Rails 8.2.0.alpha, omniauth 2.1.4, omniauth-oauth2 1.9.0,
  omniauth-google-oauth2 1.2.3, PostgreSQL test fleet on host `primary`.

## Performed

- Migrations `20261002120000_add_root_login_established_at_to_*` applied to the development and
  test app/com/org ticket databases; `db:schema:dump` regenerated the three ticket structure files.
  The app dump also gained `client_emergency_sign_in_operations`, which an earlier committed
  migration (20260926170000) had created but the committed dump omitted.
- `bundle exec rails test` (no extra environment variables): 12586 runs, 85427 assertions,
  0 failures, 0 errors, 2 skips, exit 0.
- Before the change, only a targeted baseline was taken (5 files, 49 runs, 0 failures). A full-suite
  baseline was not captured before editing; the first full run after the core change reported
  182 failures and 69 errors, all traced to tests encoding the retired restricted-session, bootstrap,
  or created_at-cooldown contract, NOTHING-status fixture tokens used as sessions, or regressions
  fixed in this change (deferred session reset during sign-up handoff, OIDC evidence redirect).
- `bundle exec rubocop` on changed Ruby files: offenses remain only in
  `app/controllers/base/{app,com,org}/roots_controller.rb` (pre-existing working-tree changes,
  Style/ImplicitRuntimeError), untouched here.
- `bundle exec brakeman -q`: one medium warning in
  `app/operations/client_emergency_secret_credential_sign_in_operation.rb:22`, unrelated.

## Not performed

- Coverage gate run; browser (system) tests; live Google sign-in; concurrency tests with independent
  database connections and synchronization points; fault injection after commit (cookie delivery
  failure); external database migration.
