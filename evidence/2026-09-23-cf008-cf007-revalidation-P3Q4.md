# CF-008 and CF-007 continuation revalidation

- Date: 2026-09-23
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained related and unrelated uncommitted changes; no commit, push,
  GitHub write, provider write, production access, or external service write was performed.

## CF-008 disposition

The current implementation was read again before any retention or scrub change. `Client` and
`Visitor` are anonymized in place by `WithdrawalPersonalDataAnonymizer`, while `Operator` is
handled by a separate physical-purge path in `RetentionPurgeJob`. Cross-database children,
credential state, retained Chronicle/audit rows, legal holds, enforcement blocks, and terminal
authentication behavior therefore do not share one safely inferable contract.

No scrub inventory schema, Operator deletion change, lifecycle reinterpretation, encryption
backfill, destructive purge, or new dry-run/preview API was added. CF-008 remains `BLOCKS_SLICE`.
This is a data-shape and irreversible-operation blocker, not a failed RetentionPurgeJob
implementation. The existing retention safety contract remains explicit and does not require a
dry-run interface.

## CF-007 disposition

The approved thirteen-cell matrix and expected registry contract were statically revalidated. The
contract reports one unique cell and logical key namespace for each approved client without
activating the compatibility registry. The repository still has no authoritative independent Side
US host source or regional audience source; the active seven-client registry remains unchanged and
the matrix continues to fail closed rather than guessing values or using a request Host header.

CF-007 is recorded as `OPEN — CONTRACT CONTRADICTION` for the pre-deployment repository scope.
This does not reopen the approved logical matrix decision and does not require production registry
or credential evidence in this pre-deployment cycle.

## Verification performed

Passed:

- Ruby syntax checks for the authority inventory and regional matrix implementation/tests.
- Targeted RuboCop: 4 files inspected, no offenses.
- Brakeman: 0 errors, 0 security warnings.
- `git diff --check`.
- Dependency-light regional contract check: 13 unique approved cells and 13 unique namespaces.

Not run / blocked:

- Rails focused tests and full suite were not started in this process because the required
  preflight cannot resolve `primary` or `valkey-kvs`; the exact failure is recorded in the prior
  environment evidence. No fallback host, application change, test skip, mock substitution, or
  service configuration change was used.
