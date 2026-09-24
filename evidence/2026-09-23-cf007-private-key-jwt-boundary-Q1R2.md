# CF-007 private-key-JWT registration boundary

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained unrelated and related uncommitted changes; no commit, push, or external write was performed.

## Change

`RegionalRpClientMatrix#binding_for` now rejects a canonical registration unless the registry
account explicitly reports `private_key_jwt` authentication. The existing namespace, exact URI,
resource-type, audience-isolation, and client-binding checks remain in force. A focused regression
case covers a registered regional client with a non-`private_key_jwt` method.

## Verification

Passed:

- `ruby -c app/values/regional_rp_client_matrix.rb`
- `ruby -c test/values/regional_rp_client_matrix_test.rb`
- `bundle exec rubocop app/values/regional_rp_client_matrix.rb test/values/regional_rp_client_matrix_test.rb`
- `git diff --check`

Not run / blocked:

- The required preflight was run with `UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example`.
- `getent hosts primary` and `getent hosts valkey-kvs` returned no records.
- `bundle exec ruby -r ./lib/local_environment -e 'LocalEnvironment.load!; load "scripts/test-environment-check"'`
  stopped with `PG::ConnectionBad: could not translate host name "primary" to address`.
- Focused Rails tests and the full Rails suite were not started because the required PostgreSQL and
  Valkey services were unavailable from this process.

No fallback host, application change, test skip, mock substitution, or service configuration change
was used to bypass the environment blocker.
