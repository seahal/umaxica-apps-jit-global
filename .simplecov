# frozen_string_literal: true

SimpleCov.load_profile "rails"
SimpleCov.command_name "Rails Tests"
SimpleCov.merge_timeout 3600
SimpleCov.cover "{app,lib}/**/*.rb"
SimpleCov.source_in_json false

# Rails' `parallelize` forks its workers, so a worker's coverage dies with the worker unless
# SimpleCov attaches itself to the fork. SimpleCov hooks `Process._fork` for this and names each
# worker's result from a stable fork serial, so repeat runs overwrite the previous run's worker
# results instead of accumulating under `merge_timeout`. Without this, a coverage run has to be
# pinned to a single worker.
SimpleCov.merge_subprocesses true

# Ruby's Coverage library reports a synthetic `else` arm for every construct with no literal `else`
# in source - `return if x`, `x&.y`, `a ||= b`, `case/when` without `else`. 6,512 of this
# repository's 15,847 measured branches were such arms and 5,727 of them were covered, because "the
# guard did not fire" is the ordinary path. Counting them reported 84.53% branch coverage; without
# them the figure is 82.14% over the 9,335 branches a test can actually take. Measure the decisions.

SimpleCov.group "Services", "app/services"
SimpleCov.group "Values", "app/values"
SimpleCov.group "Forms", "app/forms"
SimpleCov.group "Policies", "app/policies"
SimpleCov.group "Subscribers", "app/subscribers"
SimpleCov.group "Validators", "app/validators"
SimpleCov.group "Errors", "app/errors"

SimpleCov.coverage :line do
  # A global minimum is a trailing ratchet, not a target: parked at the measured figure it fails on
  # ordinary variance, and parked at an aspiration it stays red until someone disables it. Keep it
  # a couple of points below the measurement and raise it deliberately. The per-file and per-group
  # floors below, not this number, are what actually catch an untested file.
  minimum 97
  # Suite-wide averages let a file with no test hide behind well-covered neighbours.
  # Hold every file to a floor of its own.
  minimum 70, per: :file
  # Security-decision code carries a higher floor than the repository default. `per:` takes a
  # project-relative path, and a trailing slash makes it a directory prefix.
  minimum 95, per: "app/policies/"
  minimum 95, per: "app/models/"
  minimum 90, per: "app/values/"
  minimum 90, per: "app/services/"
  # Groups already at or near full coverage should not decay behind the suite-wide average.
  minimum 99, per: group("Models")
  minimum 99, per: group("Policies")
  minimum 99, per: group("Values")
  minimum 98, per: group("Services")
  minimum 98, per: group("Controllers")
  # The check that survives a growing codebase: not "are we above 97" but "did this run make it
  # worse". 0.2 points is roughly a hundred lines, wide enough for an ordinary refactor and narrow
  # enough to catch a feature that arrived without tests.
  maximum_drop 0.2
end

# Branch floors per group are deliberately not set yet: the baseline above only became meaningful
# once `ignore :implicit_else` removed the synthetic arms, and it should be observed over
# several runs before it gates a group.
SimpleCov.coverage :branch do
  ignore :implicit_else
  minimum 90
  maximum_drop 0.5
end

# Method coverage answers a question neither line nor branch coverage asks: was this method ever
# called at all. A method no test reaches is either dead code or an untested entry point, and
# neither line nor branch coverage names it.
SimpleCov.coverage :method do
  minimum 95
end

# The `maximum_drop` checks above compare against `coverage/.last_run.json`, which SimpleCov writes
# only when every check passed (`exit_handling.rb:107`), so a red run can never become the baseline
# a later run is measured against. Locally that file is simply there from the developer's previous
# green run.
#
# CI is the gap, and it is stated here rather than hidden: the `coverage` job in
# `.github/workflows/ci.yml` checks out fresh and `coverage/` is gitignored, so until that job
# restores `coverage/.last_run.json` (actions cache, keyed per branch with a fallback to the default
# branch) these two checks have nothing to compare against in CI and pass without comparing. The
# `minimum` values above are what hold there. See
# `notes/implementation/2026-09-01-simplecov-1x-coverage-settings.md` for the workflow step this needs.
