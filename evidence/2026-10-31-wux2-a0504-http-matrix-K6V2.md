# WU-X2 A05-4 social callback HTTP matrix

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had uncommitted changes, including changes affecting the tested implementation and test.
- Ran `PARALLEL_WORKERS=1 bin/rails test test/integration/social_callback_refusal_matrix_test.rb` with the local test database preparation and Preference issuer, audience and revoked-key environment configured. Result: 1 run, 1,160 assertions, 0 failures, 0 errors, 0 skips.
- The HTTP matrix includes Google and Apple unknown-subject sign-in and registered-subject sign-up, expecting a 400 refusal and no new Client, signup Flow, token or external identity. It covers additional identity states and callback outcomes as well.
- This checks the historical A05-4 refusal behavior. It does not establish WU-A9 reason-specific public responses or fresh RP entry, which remain incomplete.
