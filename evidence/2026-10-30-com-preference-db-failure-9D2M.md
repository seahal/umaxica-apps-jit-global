# Com preference database failure response

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected this check.
- Database statement and connection failures within the com write transaction are logged by error class and returned through the existing dependency-failure response. Cookie emission remains after transaction completion.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb`: 7 runs, 58 assertions, no failures or errors. An actual legacy digest uniqueness violation produced 503; the attempted new row rolled back, the original preference and Web Push value remained, and no preference or binding cookie was emitted.
- The unique digest index is contrary to two.md: a valid binding must be reusable when a new row is created. The failure test documents the current transitional behavior and must be replaced by a successful rebinding test when the independent binding schema is delivered. A commit-time failure and cryptographic key failure were not tested.
