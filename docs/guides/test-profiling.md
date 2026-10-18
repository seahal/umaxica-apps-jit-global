# Test profiling

The suite uses [TestProf](https://test-prof.evilmartians.io/) (StackProf and EventProf recipes) via
a Minitest plugin, loaded in `test/test_helper.rb`. Loading it costs nothing on an ordinary run:
`require "test_prof"` and `Minitest.load(:test_prof)` only define classes and register
`TestProf.activate` hooks that stay inert unless their environment variable is set.

## Ordinary run

```bash
bin/rails test
```

Runs the full suite in parallel (`PARALLEL_WORKERS`, default: logical processor count). No profiling
overhead.

## Finding slow individual tests

```bash
bin/rails test --verbose <path>
```

Minitest's `--verbose` reporter prints each test's name and wall time as it runs, which is enough to
spot an outlier before reaching for a profiler.

## TestProf sampling (`SAMPLE`)

```bash
PARALLEL_WORKERS=1 SAMPLE=20 bin/rails test
```

Runs only `SAMPLE` randomly selected test methods (`SAMPLE_GROUPS` selects whole test classes
instead) rather than the ~13k-test suite. Confirm the run actually stopped at N tests — the summary
line ("N runs, ...") is the source of truth, not the progress dots.

## StackProf (`TEST_STACK_PROF`)

```bash
PARALLEL_WORKERS=1 TEST_STACK_PROF=1 bin/rails test <target>
```

Profiles wall time (`TEST_STACK_PROF_MODE` can select `cpu` or `object`) across the whole run and
dumps, under `tmp/test_prof/`:

- `stack-prof-report-<mode>-raw-total.dump` — the raw StackProf dump (`Marshal`-encoded)
- `stack-prof-report-<mode>-raw-total.json` — the same data as JSON (`TestProf::StackProf` writes
  this automatically because `TEST_STACK_PROF_RAW` defaults to on)

Read it with the `stackprof` gem already in the bundle:

```bash
bundle exec stackprof --text tmp/test_prof/stack-prof-report-wall-raw-total.dump
```

or generate a flame graph — TestProf prints the exact command to run at the end of the test run.

Combine with `SAMPLE` to profile a representative slice instead of the full suite:

```bash
PARALLEL_WORKERS=1 SAMPLE=200 TEST_STACK_PROF=1 bin/rails test
```

Run this a few times with different samples (the seed changes every invocation unless `--seed` is
passed) before trusting a single StackProf report — one sample can overweight whatever happened to
be selected.

## EventProf (`EVENT_PROF`)

```bash
PARALLEL_WORKERS=1 SAMPLE=20 EVENT_PROF=sql.active_record bin/rails test
```

Prints total event count/time and the slowest suites for the named event (`sql.active_record` for
ActiveRecord queries; any other `ActiveSupport::Notifications` event name works too). Useful once
StackProf points at database-heavy code and you want a query-level breakdown instead of a call-stack
sample.

## Why `PARALLEL_WORKERS=1` for profiling

`ActiveSupport::TestCase.parallelize` forks one OS process per worker (`test/test_helper.rb`), and
both StackProf and TestProf's `EVENT_PROF`/`SAMPLE` reporters aggregate in-process. Profiling under
the normal worker count would fork before the plugin's `at_exit` hook runs, producing one StackProf
dump per worker with no combined view (and `SAMPLE`'s `Minitest::Runnable.reset` would run once per
worker, redundantly). Pin `PARALLEL_WORKERS=1` for any profiling run; leave it unset for ordinary
`bin/rails test`, where parallelism is worth keeping.

## Known limitation: fixture-cache invalidation from real-concurrency tests

`fixtures :all` (in `test/test_helper.rb`) is cheap in the common case: Rails loads all ~200 fixture
tables once per process and caches them in `ActiveRecord::TestFixtures`'s
`@@already_loaded_fixtures`, reusing that cache — inside a rolled-back transaction — for every test.
Confirmed by direct observation of that cache during a `SAMPLE=1000` run: a normal test example
costs on the order of dozens of queries, not hundreds.

A minority of tests break that cache instead of just using it. Two known patterns:

- A test class sets `self.use_transactional_tests = false` (5 such files were fixed by opting them
  out of the fixtures machinery entirely with `setup_fixtures`/`teardown_fixtures` no-op overrides,
  since they touch no database — see their inline comments). Two more
  (`test/operations/publishing/promotion_concurrency_test.rb`,
  `test/integration/sign_app_oidc_browser_flow_test.rb`) still set it deliberately and correctly,
  per their own comments, to observe real commits.
- A test spawns a real `Thread.new` that checks out its own `ActiveRecord` connection
  (`SomeModel.connection_pool.with_connection`) to exercise a genuine race (row locking, unique
  constraint races) across two independent connections. Confirmed present and confirmed to break the
  fixture cache (same probe technique as above) in:
  - `test/models/client_email_test.rb`
  - `test/models/client_telephone_test.rb`
  - `test/models/refresh_token_concurrency_test.rb`
  - `test/services/org/operator_lifecycle/invitation_acceptance_test.rb`

  (Two other files that also use `Thread.new` —
  `test/services/valkey/auth_state/sign_out_notice_store_test.rb` and
  `test/services/valkey/auth_state/authorization_code_store_test.rb` — were checked with the same
  probe and confirmed _not_ to trigger this: their threads only talk to Valkey/Redis, never to an
  `ActiveRecord` connection, so they don't touch the pinned-transaction machinery at all.)

When Rails detects that a pinned connection's transaction did not cleanly roll back (real concurrent
commits do exactly that, by design, for these tests), it clears `@@already_loaded_fixtures` for the
whole process as a safety measure. The next `fixtures :all` test anywhere in the run — not just in
the same file — then pays a full reload (~600+ queries) instead of the usual few dozen.

This is accepted as-is rather than worked around:

- Setting `use_transactional_tests = false` on these classes would make it _worse_, not better — the
  non-cached branch (`ActiveRecord::TestFixtures#setup_fixtures`'s `else` path) reloads and
  invalidates the shared cache unconditionally, on every single test in the class, rather than only
  on the specific racy example.
- Rails offers no public API to mark one test's real commits as safe to ignore for cache purposes.
- Isolating these files into a separate test run (their own Rake task, run outside the main
  `bin/rails test` invocation) would contain the blast radius, but changes how the suite is invoked
  — a call for the team, not a profiling-tooling change, so it is out of scope here.

Net effect: a `SAMPLE` or `TEST_STACK_PROF` run's SQL-time share (see Recommended workflow below)
includes some amount of this reload noise whenever the sample happens to include one of the tests
above. It is not a bug in the profiling setup — StackProf/EventProf are reporting real queries — but
it means SQL-time percentages from a single sample can overstate how expensive the _sampled_ test
itself is. Prefer several samples/seeds, per the "Repeat with a few different samples" step, when a
test's SQL share looks surprisingly high with almost no other work in it.

## Recommended workflow

1. Run the normal parallel suite and note wall-clock time.
2. Use `--verbose` to spot individual outliers.
3. `PARALLEL_WORKERS=1 SAMPLE=<N> TEST_STACK_PROF=1 bin/rails test` against a representative sample.
4. Repeat with a few different samples/seeds rather than trusting one run.
5. If SQL time looks significant in the StackProf report, follow up with
   `EVENT_PROF=sql.active_record` on the same or a smaller sample.
6. Narrow to the specific slow file/class the sample pointed at.
7. Optimize only once a real bottleneck is measured, not before.
8. Re-run the full parallel suite (`bin/rails test`, no profiling env vars) to confirm the actual
   improvement.
