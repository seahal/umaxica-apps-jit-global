# Classified self-controlled public-ID capacity gate

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty and the existing staged, unstaged and untracked paths were
preserved. The final observation for this slice contained 159 changed paths. No reset, clean,
stash, worktree, push, production operation, shared-database operation or CI run was performed.

## Red and implementation

The P12a capacity contract was expanded to the explicitly classified `CAPACITY_TABLES` inventory
in `test/models/public_id_capacity_contract_test.rb`: selected app/com/org Zenith records, ticket
and signal records, and Avatar groups, Avatars, group memberships and handles. Provider/protocol
identifiers, the ORG human-entered code and unclassified remaining candidates were excluded.

Before the new migrations, the metadata contract produced the expected Red:

```text
47 runs, 62 assertions, 42 failures, 0 errors, 0 skips
```

The implementation adds 16 migrations: an additive `NOT VALID`
`char_length(public_id) <= 25` check migration and a separate validation migration for each of
`app_zenith`, `com_zenith`, `org_zenith`, `app_ticket`, `app_signal`, `com_signal`, `org_signal`
and `avatar`. The first migration attempt exposed a loader naming mismatch before applying these
new checks; the files were renamed to match their unique migration class names and the migration
run was repeated successfully. No application row was rewritten.

## Focused Green and migration rehearsal

The focused command used the run-owned 20-database manifest
`tmp/acceptance-isolated-20261010p8b-primary.json`, `RAILS_ENV=test`, `PARALLEL_WORKERS=4`, and the
repository's `POSTGRESQL_ISOLATED_TEST_*` settings:

```text
bundle exec rails test test/models/public_id_capacity_contract_test.rb
```

Result:

```text
47 runs, 146 assertions, 0 failures, 0 errors, 0 skips
```

The app_zenith pair was individually rehearsed down/up. The remaining seven database groups were
then each run through validation down, additive down, additive up and validation up; all 28
commands exited zero. The eight affected structure-dump tasks completed successfully after the
repository-required isolated test environment variables were supplied:

```text
bundle exec rails db:schema:dump:app_zenith
bundle exec rails db:schema:dump:com_zenith
bundle exec rails db:schema:dump:org_zenith
bundle exec rails db:schema:dump:app_ticket
bundle exec rails db:schema:dump:app_signal
bundle exec rails db:schema:dump:com_signal
bundle exec rails db:schema:dump:org_signal
bundle exec rails db:schema:dump:avatar
```

The generated dumps contain 44 named `public_id_max_length` checks: the 42 checks in this slice
plus the earlier app/com principal checks. The initial dump attempt without the isolated manifest
failed during configuration loading and was not treated as a schema result; the same tasks passed
after the required environment was restored.

## Gate 2

After the focused Green and rehearsal, the full Rails suite ran against the same run-owned
manifest with four workers:

```text
bundle exec rails test
15143 runs, 128254 assertions, 0 failures, 0 errors, 0 skips
```

The four latest worker receipts all recorded `cleanup_completed: true`:

- `tmp/isolated-20261010p8b-worker-0-20261012-1738808-sf57pr.json`
- `tmp/isolated-20261010p8b-worker-1-20261012-1738808-m990ls.json`
- `tmp/isolated-20261010p8b-worker-2-20261012-1738808-c9zacm.json`
- `tmp/isolated-20261010p8b-worker-3-20261012-1738808-5ti1fq.json`

Vitest also passed locally:

```text
bun run test
99 files passed, 1140 tests passed
```

This is current disposable-environment evidence for the dirty worktree. It does not establish
shared or production data validation, a global identifier-capacity decision, public-ID immutability
for every table, the final staff-event bigint primary-key/foreign-key cutover, D-11 isolation-level
coverage, P10b/P12b Avatar cutover, host Alloy runtime verification or the privacy-retention policy.
