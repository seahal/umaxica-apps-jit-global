# Phase 09 OIDC identity binding evidence

- Commit: `bfe569a162078df62e8e3b3011367840780e3078`
- Worktree: dirty before and after the phase; pre-existing and unrelated changes were preserved.
- Disposable database: manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, run `20261003auth6f3`, all 20 databases, one worker. The shared databases were not used.
- Migrations: `CreateClientOidcIdentityBindings`, `CreateVisitorOidcIdentityBindings`, and `CreateOperatorOidcIdentityBindings` applied successfully. The empty disposable Zenith databases had no legacy rows to copy; the migration ran its unknown-audience, issuer, and actor preflight and completed the deterministic backfill with zero copied rows.
- Test command: `bin/rails test test/models/oidc_identity_binding_test.rb test/controllers/concerns/oidc/callback_test.rb`
- Observed result: `28 runs, 126 assertions, 0 failures, 0 errors, 0 skips`.
- Additional checks: `bin/rails zeitwerk:check` passed; targeted `bundle exec rubocop` passed for 17 changed Ruby files.
- Coverage exercised exact `(issuer, subject, audience)` lookup, several audiences on one canonical identity, both binding uniqueness constraints, first binding from an authoritative resource, mismatch rejection, canonical selector preservation, and Persona preservation.
