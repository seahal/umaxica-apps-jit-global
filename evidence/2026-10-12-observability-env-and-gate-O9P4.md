# Observability environment branch and current full gate

- Date: 2026-10-12
- Repository: `/home/global/workspace`
- Branch: `feature`
- HEAD at verification: `b5a4f246bd8778cd8f1e5e0e9ae3758b260f0178`
- Worktree: intentionally dirty with pre-existing application, test, configuration and document
  changes; this slice preserved them and did not reset, clean, stash, rebase, merge, create a
  worktree, push, use CI, use Podman or access production/shared destructive resources.
- Database scope: the run-owned twenty-database manifest
  `tmp/acceptance-isolated-20261010p8b-primary.json` on the configured test host. No shared or
  production database was targeted.

## Change

`config/initializers/opentelemetry.rb` no longer uses a two-argument `ENV.fetch` default for the
optional `OPEN_TELEMETRY` toggle. It explicitly treats a missing or `false` value as disabled and
raises for any non-empty value other than `true` or `false`. The exporter/instrumentation path is
unchanged when enabled; no collector, Compose or host mount was changed.

The installed `opentelemetry-instrumentation-action_mailer` version is `0.8.1`. Its checked-in gem
source documents and implements `notification_payload_transform`, `process_payload_transform` and
`email_address: :omit`, which are the options used by the existing initializer. No private
instrumentation API was added.

## Checks

1. `ruby -c config/initializers/opentelemetry.rb` — PASS (`Syntax OK`).
2. Guarded focused command, with the manifest names supplied as the comma-separated
   `POSTGRESQL_TEST_PREPARE_DATABASES` value:

   ```text
   RAILS_ENV=test PARALLEL_WORKERS=1 POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b \
   POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json \
   POSTGRESQL_TEST_HOST=primary POSTGRESQL_DATABASE=postgres \
   POSTGRESQL_TEST_PREPARE_DATABASES=<the twenty names from the manifest, comma-separated> \
   bundle exec rails test \
   test/unit/security/opentelemetry_initializer_test.rb \
   test/unit/security/action_mailer_logging_policy_test.rb \
   test/unit/security/observability_span_scrubber_test.rb \
   test/unit/security/filter_parameter_logging_test.rb
   ```

   Result: `21 runs, 104 assertions, 0 failures, 0 errors, 0 skips`.

3. Guarded Rails Gate 2 with the same run-owned manifest and `PARALLEL_WORKERS=4`:
   `bundle exec rails test` — PASS, `15194 runs, 128472 assertions, 0 failures, 0 errors, 0 skips`,
   332.937657 seconds.
4. `bun run test` — PASS, `99` files and `1140` tests.
5. `bundle exec ruby` inspection of the installed gem — PASS, version `0.8.1`; the documented
   transform and email-address options are present in the installed README and implementation.

An initial unwrapped focused Rails command was rejected before test loading because its inherited
four-database preparation scope omitted sixteen configured writer databases. It is recorded as an
environment-preparation refusal, not as a test result. The guarded rerun supplied the complete
manifest and passed.

## Limits

This record does not prove host-side Compose recreation, effective core read-only mounts, Alloy
syntax/runtime processing, production collector behavior, live mail delivery or external sinks. It
also does not close the separate OTP-observability owner/security-review decision; those remain
explicitly deferred by the current acceptance documents.
