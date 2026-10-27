# Full-suite repair: architecture baseline

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree was dirty with existing cycle changes and the changes measured here.
- Before regeneration, compared `ArchitectureBaseline.measure` against the currently recorded per-file counts. No file had a new or increased offense count.
- `bin/rails architecture:baseline` removed the entries for `acme_logout_transactionable.rb`, `acme_logout_transaction.rb`, and `acme_logout_transaction_coordinator.rb` from both generated artifacts, following the D-185 / SO-1 removal. No entries were added.
- `PARALLEL_WORKERS=1 bin/rails test test/tooling/architecture_baseline_test.rb`: 3 runs, 2,580 assertions, 0 failures, 0 errors, 0 skips.
- Exploratory run of `test/controllers/auth/app/sign_in_admission_test.rb`, `test/integration/preference_entry_recovery_test.rb`, `test/integration/totp_registration_boundary_test.rb`, `test/integration/auth_region_contract_test.rb`, and `test/integration/sign_entry_sentry_test.rb`, with `PARALLEL_WORKERS=1`: 63 runs, 273 assertions, 20 failures, 5 errors, 0 skips. Several tests still post a removed admission form after the Design D redirect; this is more than a status-only change. No assertions in these files were changed.
- The item 5 and 6 findings remain as recorded in `2026-10-27-full-suite-repair-H2N6.md`. The batch is incomplete, as are the later batches and final full-suite comparison.
