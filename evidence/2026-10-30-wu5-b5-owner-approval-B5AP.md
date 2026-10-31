# WU-5 B-5 owner approval record

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree carries the uncommitted WU-3/4/5/7 body.
- Approval: on 2026-10-30 the owner stated in the session, "B-5 ですが、この件は承認します。"
  This approves B-5 for the WU-5 destructive operations recorded in
  `evidence/2026-10-29-wu5-com-db-removal-ticket-Q4X8.md` and
  `evidence/2026-10-29-wu5-test-db-rebuild-Q4X8.md` (local Dev Container dev/test databases only).
- Timing: the approval is retroactive. The drops were executed on 2026-10-29 and no approval was
  recorded in those tickets. This record does not claim an approval existed before the drops.
- Scope not covered: production or Neon application of the two irreversible drop migrations
  (`db/chronicle_migrate/20261029120000_*`, `db/avatars_migrate/20261029120100_*`) and any
  development-database application of them. Each needs its own approval.
- Still open (unchanged): `.github/workflows/ci.yml` lists dropped com databases (read-only mount);
  `db:verify_no_schema_drift` reports four pre-existing role-digest mismatches.
