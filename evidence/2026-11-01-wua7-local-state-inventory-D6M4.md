# WU-A7 local actor state inventory

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 660 modified or untracked
  entries; no application, test, or schema files were changed for this read-only inventory.
- With `.env.container.devcontainer` loaded, the development database has 0 Clients and 0 Operators.
- The test database has 7 Clients (status 11: 6; status 13: 1) and 6 Operators (status 2: 5; status
  3: 1). The statuses are registration/account statuses, separate from the proposed withdrawal axis.
- All 7 test Clients have no `withdrawal_started_at`, `deactivated_at`, or `terminated_at`; none has
  a finite `withdrawn_at`. Their `withdrawn_at` values are PostgreSQL Infinity. Their
  `recovery_available_at` and `early_termination_available_at` are NULL. The Client table has 0
  withdrawal flows.
- All 6 test Operators have no `withdrawal_started_at`, `deactivated_at`, or `withdrawn_at`. The
  test `OperatorLifecycleRequest` rows group as 2 pending withdrawals, 1 approved withdrawal, and 1
  pending join; none is executed.
- The Client rows have `discard_at` and `purge_eligible_at` at 2046-11-01 and 2046-11-02
  respectively. The retention contract keeps those columns separate from actor withdrawal state;
  their values were not used to classify lifecycle state.
- The observed local actor rows have no withdrawal evidence to map. No actor state was backfilled
  and no migration was run. No A7 tests were run in this inventory.
- A current contract mismatch remains for ORG: `OrgOperatorLifecycleExecute`'s `suspend` action is
  an indefinite leave with no deletion countdown and may be restored at any time, while `two.md`
  §6.3 requires a deadline for `recoverable_suspended`. Owner mapping is pending.
- An initial shell-quoted development query did not run; a later read-only query completed and
  returned the counts above. An earlier test query referenced a nonexistent Operator `terminated_at`
  column and stopped after its Client output; the corrected per-model query completed. Neither
  failed query wrote to a database.
