# Email ceremony owner locking

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including those under test.
- The new withdrawn-owner test failed against the earlier ordering: the Ticket transaction was consumed before the owner was rejected. It passed after locking the owner and candidate and checking owner availability before consumption.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/identity_email_ceremony_final_committer_test.rb` passed: 16 runs, 52 assertions, no failures or errors.
- The operation suite includes legacy fake collaborators. Independent-connection race coverage and all configured surfaces were not verified.
- The combined contact finalization and source-audit tests passed: `PARALLEL_WORKERS=1 bin/rails test test/operations/contact_ceremony_source_audit_test.rb test/operations/identity_email_ceremony_final_committer_test.rb test/operations/identity_telephone_ceremony_final_committer_test.rb`, 41 runs, 198 assertions, no failures or errors.
