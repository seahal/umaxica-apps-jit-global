# R3-WU07 current isolated full-suite evidence

Date: 2026-10-16 UTC  
Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`  
Worktree: uncommitted R1/R2/R3 source, migration, documentation, test and evidence changes were
present; unrelated work was preserved.

The fresh isolated R3 fleet `20261016r3a1` was used with eight Rails test workers. The command set
`POSTGRESQL_TEST_PREPARE_DATABASES` from the manifest and loaded `bin/rails test`:

```text
RAILS_ENV=test PARALLEL_WORKERS=8 \
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261016r3a1 \
POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/acceptance-isolated-20261016r3a1.json \
POSTGRESQL_TEST_HOST=primary \
bundle exec ruby -rjson -e '...; ARGV.replace(["test"]); load "bin/rails"'
```

Observed result:

```text
15376 runs, 130675 assertions, 0 failures, 0 errors, 0 skips
```

The run includes the current session-limit, Core Browser API, Browser RP, R2 and R3 behavior
changes. This resolves the earlier application-test failures recorded under R3-WU07 for this
worktree. It does not close the unwritable CI workflow or repository-wide schema-drift findings.
