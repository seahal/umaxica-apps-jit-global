# O-10 lock candidate scan

- Date: 2026-11-04
- Full git HEAD: `b30345216886c98af1f04cbd434f067f12decf01`
- Worktree: extensively uncommitted; scan used the current worktree source.
- Scope: regenerate a narrower lexical candidate set for the OP/principal lock-order inventory.
- Commands: intersected the file lists from
  `rg -l 'with_lock|\.lock\b|lock!|with_cycle_lock' app --glob '*.rb'` and
  `rg -l 'OpBase|ClientStepUpCeremonyTransaction|OperatorStepUpCeremonyTransaction|ClientOidcAuthorizationTransaction|OperatorOidcAuthorizationTransaction|ClientAuthCeremonySession|OperatorAuthCeremonySession' app --glob '*.rb'`;
  compared each resulting path with the current `lock-order-inventory.md` using a read-only Python 3
  script.
- Result: 88 files matched; 80 were not mentioned as full paths in the inventory. This includes
  likely false positives and paths already covered by grouped dispositions. It is a triage set, not
  80 confirmed reverse edges. The earlier 114 count used a broader search expression and is not
  numerically comparable.
- Verification: source search only; no tests or database operations were run.
