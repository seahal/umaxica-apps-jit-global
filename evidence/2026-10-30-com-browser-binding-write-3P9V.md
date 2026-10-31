# Com consent and Web Push browser binding writes

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree had uncommitted changes affecting the checks.
- Com consent and Web Push writes now reject a mismatched existing browser binding before changing the digest; the transaction rolls back. This prevents a consent write from transferring an existing enabled Web Push setting to a different browser. This is a temporary restriction: the final independent-binding design must implement the specified rebinding behavior without transferring unrelated settings.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_retired_consent_test.rb test/models/com_preference_web_push_test.rb`: 9 runs, 49 assertions, no failures or errors. Coverage includes a valid session CSRF token, a missing token, a retired row, and mismatched binding writes.
- The new standalone binding table, complete rebind semantics, generated structure, and the rest of two.md remain incomplete.
