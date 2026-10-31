# Dormant adult gate boundary

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had uncommitted changes affecting the checks.
- Added a static guard against adult gate references in controllers, services, values, policies, helpers and JavaScript; model-layer definitions remain allowed. This supplements, rather than replaces, the registry, real app/org rotation and com write tests.
- With automatic schema maintenance disabled because the com binding migration remains pending, the guard, rotation and com initialization tests passed: 4 runs, 34 assertions. `bundle exec rubocop test/unit/security/preference_dormant_adult_gate_test.rb` reported no offenses.
- `docs/architecture/preference.md` still describes com/visitor adoption and parent-recency reconciliation, while current com authentication has been retired and current app/org reconciliation is per-key. The existing legacy adoption also differs from two.md's one-way sign-in contract. End-to-end app/org sign-in verification and the broader two.md implementation remain incomplete.
