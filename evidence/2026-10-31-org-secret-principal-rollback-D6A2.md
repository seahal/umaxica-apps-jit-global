# ORG Secret creation principal rollback probe

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting this result.
- A temporary non-transactional local test invoked the live Secret creator inside an operator Zenith transaction and explicitly rolled that enclosing transaction back after the call returned. It passed 1 run and 3 assertions: the Secret row was absent, while the creation Chronicle event remained and the Ticket Step-Up evidence was consumed.
- The probe removed its own synthetic audit, token, device and operator records and was removed from the persistent test suite because it describes an unresolved defect, not the intended contract.
- This confirms a later enclosing principal rollback can leave a misleading audit in the current local implementation. It does not establish every failure boundary, concurrent behavior or production state. The same-principal-database audit fact and XDB-11 remain incomplete.
