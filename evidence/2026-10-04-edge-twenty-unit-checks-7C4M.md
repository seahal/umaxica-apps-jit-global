# Edge twenty-unit checks

Observed completed results 2026-10-04, 05:47 UTC (Etc/UTC); root Vitest started
05:45:19 UTC. Edge main HEAD 185dd076404011ed391b2b550091be3fd7939ba0,
84 dirty paths. Rails feature HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5,
420 dirty paths. Results include concurrent uncommitted work and are not CI.

The sequential check process completed each existing `pnpm --dir <unit> run check`
with exit 0 for all twenty units:

- app/apex, app/core, app/docs, app/help, app/info, app/news.
- com/apex, com/core, com/docs, com/help, com/info, com/news.
- dev/apex and net/apex.
- org/apex, org/core, org/docs, org/help, org/info, org/news.

The process also completed these root commands with exit 0:

- `pnpm exec vitest run --dir test`: 12 files passed, 433 tests passed,
  one existing conditional test skipped. The skip is the Compose merge test when
  no Compose engine is available; it was not introduced or changed here.
- `pnpm run check:workers`.
- `pnpm run check:architecture`.
- `pnpm run check:deps`.
- `pnpm run check:spelling`.

Commands used the existing pnpm tool installation on PATH; root Vitest received
the current tracked-file list through the existing EDGE_TRACKED_FILES interface.
Per-command exit codes and logs were inspected from the completed process results.
No check threshold, skip, dependency or configuration was changed by this run.

These checks cover the existing per-unit scripts and repository invariants. They
do not prove Rails authentication integration, refresh continuation or production
routing/cache behavior. NOT_RUN in this process: all-unit builds, all-unit browser
tests, Rails/browser authentication integration, CloudFront checks or deployment.
The separate Core history evidence records the three Core browser/build checks.
