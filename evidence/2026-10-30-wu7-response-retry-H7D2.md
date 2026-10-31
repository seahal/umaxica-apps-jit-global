# WU-7 retry after an undelivered preference response

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Staged, unstaged and untracked work affected the result.
- The existing test for a post-commit response-read failure passed before extension: 1 run, 7 assertions. It now starts a fresh HTTPS integration session carrying the pre-write JWT, representing a browser that did not receive the newly issued credential, and retries a theme write.
- The old committed row and dark theme remained unchanged; the stale JWT produced a distinct preference with the explicitly submitted light theme and default consent, no binding and disabled Web Push. This exercises the response-loss retry rule, not an actual network disconnect or header queue failure.
- The response-binding, write journey, commit-failure and concurrent save/reset files passed: 52 runs, 823 assertions, zero failures, errors or skips. RuboCop passed on the modified test. Full-suite comparison remains outstanding; no migration or non-test purge was run.
