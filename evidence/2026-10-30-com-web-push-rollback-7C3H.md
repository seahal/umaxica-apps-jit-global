# Com Web Push issuance failure rollback

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; the worktree contained uncommitted changes affecting the checks.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb`: 6 runs, 43 assertions, no failures or errors. The new case uses a real database option outside the token allowlist, then requests a Web Push change through the public endpoint. Token generation is refused, the response is 503, and the old Web Push value, JWT generation and binding digest remain unchanged; no preference or binding cookie is issued.
- The case exercises payload validation before signing, not a cryptographic key failure or a database commit failure. Those cases and the remaining two.md requirements remain unverified.
