# Com browser binding expiry

- Commit: `336811e5072a93c0523e484f905082635b28f48f`; uncommitted changes affected these checks.
- The com preference write boundary returns the issuance snapshot after commit. Consent and Web Push saves use its expiry for the host-only binding cookie, so it shares the signed token's database-clock expiry instead of using the application clock after commit.
- `bin/rails test test/integration/anonymous_com_web_push_api_test.rb test/integration/anonymous_com_web_push_initialization_test.rb test/integration/anonymous_com_preference_response_binding_test.rb`: 8 runs, 39 assertions, no failures or errors. The Web Push and consent paths each compare the binding cookie expiry to the signed token expiry.
- The tests ran against the existing test database with the Web Push migration already applied. The independent binding schema, full rebinding behavior, and other two.md requirements remain incomplete.
