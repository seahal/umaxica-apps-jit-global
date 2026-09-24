# Retention purge batch boundary hardening

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained related and unrelated uncommitted changes; no commit, push,
  GitHub write, provider write, production access, or external service write was performed.

## Change

`RetentionPurgeJob#perform` now validates the caller-provided batch size before the kill-switch
check or any cleanup. Only integer values from 1 through 500 are accepted; integral strings remain
accepted for Active Job argument compatibility. Fractional, zero, negative, missing, and oversized
values raise `ArgumentError` rather than being truncated or passed to `in_batches`.

This strengthens the existing explicit/bounded retention contract. It does not add a dry-run,
preview, simulation API, schema, audit event, or new deletion path.

## Tests and verification

Added public-job boundary coverage for:

- 1 and 500 as inclusive accepted boundaries;
- 501, zero, negative, nil, and fractional values as rejected inputs; and
- an integral string accepted before destructive work.

Passed:

- `ruby -c app/jobs/retention_purge_job.rb`
- `ruby -c test/jobs/retention_purge_job_test.rb`
- targeted RuboCop: 2 files inspected, no offenses;
- Brakeman: 0 errors, 0 security warnings;
- `git diff --check`.

Not run / blocked:

- `test/jobs/retention_purge_job_test.rb` could not be started because the required Rails preflight
  cannot resolve `primary` (`PG::ConnectionBad: could not translate host name "primary" to address:
  Temporary failure in name resolution`). `getent hosts primary` and `getent hosts valkey-kvs`
  returned no records in the current `global-devcontainer-core` process. No localhost fallback,
  mock substitution, test removal, skip, or service configuration change was used.
