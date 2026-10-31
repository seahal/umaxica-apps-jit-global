# Session and admission documentation reconciliation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree contained extensive uncommitted changes affecting the check.
- Reconciled the current session-limit documentation with the inspected APP/ORG token limits, Visa limitation controllers, and `AuthenticationBase` resolution issuance. Removed current claims about the retired COM authentication realm, marked historic three-realm delivery as historic, and corrected the contradictory statement that session-limit resolution writes nothing and moves the parent to `SESSION_LIMIT_PENDING`.
- Reconciled the Auth ceremony boundary note with the retained APP/ORG models and confirmed-entry GET behavior. The existing navigation-metadata enforcement gap is stated explicitly; this edit does not fix it.
- `PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/session_limit_gate_test.rb test/controllers/concerns/session_limit_model_refusal_test.rb` passed: 10 runs, 35 assertions, no failures, errors or skips. Scoped `git diff --check` passed. These checks do not establish every session-limit or admission transition.
