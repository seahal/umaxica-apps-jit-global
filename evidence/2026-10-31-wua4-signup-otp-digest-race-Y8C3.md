# APP signup OTP issuer destination binding race

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted application and test changes.
- The existing independent-connection issuer race test was expanded to cover both deadline and destination-digest changes while an issuer waited on its transaction row. Both Email and Telephone return `binding_mismatch`, leave the OTP generation unissued and retain the Source cooldown.
- The race, Email/Telephone issuer and existing delivery-concurrency files passed together: 39 runs, 438 assertions, no failures or errors. A prior run had two test assertion failures because the Telephone cooldown was nil and the assertion used `assert_equal`; the check now compares unchanged values without assigning a meaning to nil. Scoped RuboCop passed.
- The competing transaction writer was synthetic and bypassed the normal parent lock; a production path that produces this interleaving and external delivery remain unverified. The test cleans up only its own synthetic rows.
