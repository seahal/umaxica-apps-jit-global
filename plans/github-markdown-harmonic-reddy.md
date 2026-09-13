# CI workflow fixes (.github/workflows only)

## Context

A static/dynamic-analysis tightening pass could not touch `.github/` in its own environment, so
three CI defects were left behind:

1. `ci.yml` calls `bundle exec brakeman`, bypassing `bin/brakeman`, whose only purpose is to force
   `--ensure-latest`. The staleness guard is therefore inert in CI — an outdated Brakeman would
   silently scan with old check definitions.
2. The `coverage` job is capped at `timeout-minutes: 30`, but `test/test_helper.rb` pins Minitest to
   a single worker when `COVERAGE=true`. A 4-worker local full suite takes 343 s, so a single-worker
   run plus `bundle install` and `bin/rails db:prepare` sits uncomfortably close to the cap.
3. `.simplecov` deliberately leaves `refuse_coverage_drop` unset because CI never restores
   `coverage/.last_run.json` (gitignored; uploaded as an artifact only). Enabling it today would be
   a no-op that reads as a guarantee.

Scope is strictly `.github/workflows/`. No application code, `.rubocop.yml`, `.simplecov`, or
`config/` changes.

## Changes

All edits in `.github/workflows/ci.yml`.

### 1. Brakeman via the wrapper (line 99)

```yaml
run: bin/brakeman -f sarif -o brakeman.sarif --no-pager --quiet -z
```

`bin/brakeman` already does `require "bundler/setup"`, so no `bundle exec` prefix is needed.

### 2. Coverage job timeout (line ~303)

`timeout-minutes: 30` → `timeout-minutes: 45` on the `coverage` job.

### 3. Restore `coverage/.last_run.json` so `refuse_coverage_drop` can work

Add a restore step before `Run Rails tests with coverage`, and a save step after it, using
`actions/cache/restore` + `actions/cache/save` (split, not the combined `actions/cache`) so that
only default-branch runs publish a baseline and pull requests can read but never poison it.
`actions/cache` is currently unused in this repository; pin it to a version tag to match the
existing style (e.g. `actions/cache/restore@v4.3.0`).

Restore, immediately after `Setup test databases`:

- `path: coverage/.last_run.json`
- `key: coverage-last-run-${{ github.sha }}`
- `restore-keys: coverage-last-run-`
- `id: coverage-baseline` (its `cache-matched-key` output makes a miss visible in the log)

Save, after the test step, guarded so only the default branch writes the baseline:

- `if: success() && github.event_name == 'push' && github.ref == format('refs/heads/{0}', github.event.repository.default_branch)`
- same `path` and `key: coverage-last-run-${{ github.sha }}`

Notes to carry into the report:

- GitHub cache scoping lets a PR read caches from its base branch, so PR runs get the default
  branch's last successful baseline — the intended comparison.
- The first run after this lands is a cache miss, and SimpleCov passes on a missing
  `.last_run.json`. The guard becomes effective from the second default-branch run.
- Saving only on `success()` means a failing run never lowers the baseline.

### 4. Tools configured but never run in CI — not added

`i18n-tasks`, `packwerk`, `annotaterb`, `debride`, `flog`, `flay` stay out of CI for now. The task
required measuring local output volume before gating, and that could not be done: `bundle exec`
fails in this worktree because the Gemfile's git-sourced Rails checkout is not installed
(`https://github.com/rails/rails.git (at main@2ecdae9) is not yet checked out`), and
`bundle install` is a state change outside the agreed scope. Adding an unmeasured gate risks a
permanently red job. `reek` is intentionally excluded (gem already removed).

## Verification

```bash
actionlint .github/workflows/ci.yml     # or: podman run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color
```

Then confirm by reading the diff that only `.github/workflows/ci.yml` changed:

```bash
git diff --stat -- .github
git status --porcelain
```

Full end-to-end confirmation of the cache behaviour requires a push: the first default-branch run
logs a cache miss and saves a baseline; the next run should log a `coverage-last-run-` restore hit.
