# ORG enforcement ordering

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted worktree changes affected the tests.
- The nontransactional enforcement race file passed before the additions (7 runs, 38 assertions). Two ORG races now use independent PostgreSQL connections: one ends a Case while another blocking Case is applied before its unlock; the other verifies that end waits for the in-flight operator lock and subsequently releases it.
- In the second race PostgreSQL reported the end connection blocked by the apply connection, and an independent reader observed the Source stop event before the stubbed OP delivery call. The expanded file passed (9 runs, 49 assertions, no failures or errors); scoped RuboCop passed.
- These are local tests using stubbed OP delivery. They do not establish real OP processing, ORG retry-versus-end concurrency, overlapping retry idempotency, or the end-audit recovery path.
