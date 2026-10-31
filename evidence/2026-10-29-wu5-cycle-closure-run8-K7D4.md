# WU-5 cycle closure: run8 convergence and final corrections

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; full uncommitted WU-3/4/5 worktree; nothing committed.
- run8 (`bin/rails test`, same fleet and command as run6/run7): **16,071 runs, 132,951 assertions,
  127 failures, 124 errors, 0 skips. Failing-identifier baseline comparison: 217 identifiers and
  ZERO non-baseline failures.** Every failing identifier is in
  `plans/2026-10-28-baseline-failing-tests.md` (the WU-0 baseline record).

## Outcome and deltas across run5–run8

- run5: 5 non-baseline (documented in evidence/2026-10-29-wu5-convergence-run5-fix-cycle-K2P6.md).
- run6: 3 non-baseline (CSRF class-state worker-order flake, seen only under full parallelism;
  evidence/2026-10-29-wu5-run7-csrf-flake-diagnosis-K5V2.md).
- run7: 1 non-baseline (same class-state flake, second observation).
- run8: 0 non-baseline — the flake did not reproduce with the unchanged tree; recorded as ordering
  flake observation, not a product defect. Product/app corrections verified by the suites since run5
  remain: `resource_identity` Bureau arm restoration, database.yml Neon counters
  (17/15), architecture baseline regeneration.

## Corrections this cycle

- `test/controllers/auth/ceremony_admission_boundary_test.rb`: rubocop -A cleanup (6 autocorrectable
  offenses) on the file carrying the flake; 4-file rubocop run (the file, the two WU-5-touched ops
  files, and the database config test) ends with "no offenses detected".
- Final docs changes verified in the index: the 39 visitor diagrams moved to
  `docs/mermaid/archive/visitor-com-retired/`, README and transition-inventory updated (staged as
  `R`/`M`; index code `39 R, 2 M` for docs/mermaid before later adds).

## Standing (unchanged, non-WU-5)

- `bin/rails db:verify_no_schema_drift` pre-existing role-digest mismatch on four dumps
  (app_zenith, avatar, chronicle, org_zenith) — recorded in the WU-5 removal ticket.
- `.github/workflows/ci.yml` remains un-updatable in this session (read-only mount) and still lists
  the dropped com test databases.
