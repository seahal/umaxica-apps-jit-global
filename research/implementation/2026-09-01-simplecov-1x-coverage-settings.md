# SimpleCov 1.x Coverage Settings Implementation Notes

## Context

- Original plan/spec: adopt the SimpleCov 1.x features `.simplecov` was not using, and re-baseline
  the thresholds against what the suite actually measures.
- Related decisions/docs/plans: `.simplecov` (the settings and their rationale live in its
  comments), `.github/workflows/ci.yml` (`coverage` job), `test/test_helper.rb` (worker count).
- Implementation date: 2026-09-01.
- Installed version: simplecov 1.1.1, Ruby 4.0.6 (`Coverage.supported?` is true for lines, branches,
  methods, and eval).

`.simplecov` was already written against the 1.x DSL (`cover`, `group`, `coverage :line do`,
`source_in_json`) and used no deprecated call, so nothing here is a migration. What follows is the
set of 1.x capabilities that were never picked up, plus the thresholds that were re-derived from
measurement rather than inherited.

## Decisions Made During Implementation

- Decision: `SimpleCov.merge_subprocesses true`, and `test/test_helper.rb` no longer pins a coverage
  run to one worker.
  - Why: SimpleCov 1.1 hooks `Process._fork` so Rails' `parallelize(workers:)` children keep
    recording, and names each child's result from a stable fork serial rather than its pid, so
    repeat runs overwrite the previous run's worker results instead of accumulating under
    `merge_timeout`. Measured on this suite: 947s pinned to one worker, 502s across 16, with all 17
    resultsets (parent plus workers) merging into one report.
  - Alternatives considered: leaving the pin in place and accepting a 16-minute CI job.
  - Follow-up needed: none. `ParallelTestDatabaseCloner.install!` already handles the multi-worker
    path; it is the same path every non-coverage run takes.

- Decision: `SimpleCov.ignore_branches :implicit_else`.
  - Why: Ruby's Coverage library reports a synthetic `else` arm for every construct with no literal
    `else` in source (`return if x`, `x&.y`, `a ||= b`, `case/when` without `else`). 6,512 of the
    15,847 branches this repository measured were such arms, and 5,727 of them were already covered
    because "the guard did not fire" is the ordinary path. They inflated the headline figure
    (84.53%) while burying the branches a test can actually take (82.14% over 9,335).
  - Alternatives considered: `ignore_branches :eval_generated` was evaluated and rejected — this
    repository reports zero branches attributed to `delegate` / association / `enum` macro lines, so
    it would do nothing.
  - Follow-up needed: branch floors per group were deliberately left unset until this new baseline
    has been observed over several runs.

- Decision: thresholds are trailing ratchets, roughly 1.5-2 points below the measurement, raised by
  hand when the suite clears the next step — never parked on the measured figure.
  - Why: a threshold set at the measurement fails on ordinary variance; one set at an aspiration
    stays red until someone disables it. Both destroy the signal the gate exists to carry.
  - Alternatives considered: line 99 against a measured 99.05% was tried first and rejected — about
    ten lines of slack over 54,017, so a legitimate refactor that deletes a well-covered file turns
    CI red for a reason unrelated to test quality.

- Decision: the per-file and per-group floors, not the global `minimum`, are where the enforcement
  lives.
  - Why: a global percentage over 2,496 files barely moves when one untested file arrives; a
    per-file floor fails immediately, and a per-group floor stops a strong area from decaying behind
    the suite-wide average. Floors were set just under the measured group values.
  - Follow-up needed: `minimum_per_file 70` is currently at its ceiling — the lowest file in the
    repository is 71.43%. See follow-ups.

- Decision: method coverage is enabled and gated at 93 against measurements of 94.59% and 95.17% on
  two runs of the same commit.
  - Why: it answers a question neither line nor branch coverage asks — was this method ever called
    at all. Its practical value is the list (`bundle exec simplecov uncovered --criterion method`),
    which names dead code and untested entry points; the percentage itself largely restates line
    coverage, so the gate is kept loose deliberately. It is also the criterion with real run-to-run
    variance (0.58 points between those two runs), which is a second reason not to park its
    threshold near the measurement.

## Deviations From Plan

- Change: `maximum_drop` is enabled (line 0.2, branch 0.5) but its CI half is not in place.
  - Why: `.github/` is a read-only mount in this environment, so the workflow step could not be
    written here. `.last_run.json` is written only when every check passed
    (`simplecov/exit_handling.rb:107`), so a red run can never poison the baseline — the design is
    safe, only the CI plumbing is missing.
  - Risk: until the step lands, the two drop checks are live locally (developers have
    `coverage/.last_run.json` from their previous green run) but pass without comparing anything in
    CI, because the job checks out fresh and `coverage/` is gitignored. This is the same trap the
    previous `refuse_coverage_drop` comment warned about; the trailing comment in `.simplecov` now
    names it explicitly instead of reading as a guarantee.
  - Follow-up: add these steps to the `coverage` job in `.github/workflows/ci.yml`, around the
    existing `Run Rails tests with coverage` step:

    ```yaml
    - name: Restore coverage baseline
      uses: actions/cache/restore@v4.3.0
      with:
        path: coverage/.last_run.json
        key: rails-coverage-baseline-${{ github.ref_name }}-
        restore-keys: |
          rails-coverage-baseline-${{ github.ref_name }}-
          rails-coverage-baseline-${{ github.event.repository.default_branch }}-
    - name: Run Rails tests with coverage
      run: COVERAGE=true bin/rails test test/
    - name: Save coverage baseline
      if: success()
      uses: actions/cache/save@v4.3.0
      with:
        path: coverage/.last_run.json
        key: rails-coverage-baseline-${{ github.ref_name }}-${{ github.sha }}
    ```

    Restore and save are split deliberately: the combined `actions/cache` action saves in a post
    step, and the baseline should only advance after a green run. Pin the action version the way the
    rest of the workflow pins its actions, and verify the first run on the default branch seeds the
    cache before expecting a PR to compare against it.

- Change: an earlier estimate in this session put the post-`implicit_else` branch figure at 78.83%.
  - Why: that came from a throwaway script whose regexp mis-parsed some Coverage branch keys, so it
    under-removed synthetic arms. Re-parsed positionally, the calculation reproduces SimpleCov's own
    output exactly (7,668/9,335). The measured figure is 82.14%.
  - Risk: none remaining; the number in the `.simplecov` comment is the corrected one.

## Review Notes

- Tests run:
  - `COVERAGE=true bin/rails test` (16 workers): 12,137 runs, 66,810 assertions, 0 failures, 0
    errors, 1 skip, 502s. Line 99.05% (53,508/54,017), branch 82.14% (7,668/9,335), method 94.59%
    (9,570/10,117). Every threshold check passed.
  - `bundle exec rubocop test/test_helper.rb`: clean. `.simplecov` is not in RuboCop's inspection
    set.
  - `COVERAGE=true PARALLEL_WORKERS=1 bin/rails test` (comparison run): 12,137 runs, 0 failures, 0
    errors, 1 skip, 1,108s. Line 99.05% (53,508/54,017) - identical to the parallel run, so the
    forked workers lose no coverage. Branch 82.15% (7,669/9,335), one branch apart. Method 95.17%
    (9,629/10,117), 59 methods apart.
  - Run-to-run variance this establishes, and the reason the `maximum_drop` values are what they
    are: line 0.00 points, branch 0.01, method 0.58. The two suite runs used different random seeds
    and differed by 593 assertions, so some tests genuinely took different paths; method coverage is
    the criterion that notices, which is also why no drop check is set on it.
- Tests not run: none outstanding.
- Follow-up items to promote into `plans/`:
  - Ten files sit below 80% line coverage (lowest 71.43%,
    `app/controllers/core/org/configurations_controller.rb`). Cover them and raise
    `minimum_per_file` from 70 to 80 — a smaller and better-aimed job than chasing the global
    percentage.
  - Branch coverage per file is not gated and cannot be yet: among files with four or more branches,
    the 5th percentile is 50% and the lowest is 0%
    (`app/consumers/identity_social_ceremony_result_consumer.rb`).
  - Add branch `minimum_per_group` floors once the `implicit_else` baseline has held over several
    runs.
- Operating rule worth keeping: thresholds move up, never down. If a threshold has to be lowered,
  record why the test gap cannot be closed instead of quietly relaxing the number.
